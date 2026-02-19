package com.gr3gorywolf.yamata_launcher.utils

import android.util.Log
import net.sf.sevenzipjbinding.*
import net.sf.sevenzipjbinding.impl.RandomAccessFileInStream
import java.io.File
import java.io.RandomAccessFile

private fun detectArchiveFormat(file: File): ArchiveFormat {
    val name = file.name.lowercase()

    return when {
        name.endsWith(".zip") -> ArchiveFormat.ZIP
        name.endsWith(".rar") -> ArchiveFormat.RAR
        name.endsWith(".7z") -> ArchiveFormat.SEVEN_ZIP
        name.endsWith(".tar") -> ArchiveFormat.TAR
        name.endsWith(".gz") || name.endsWith(".tgz") -> ArchiveFormat.GZIP
        name.endsWith(".bz2") || name.endsWith(".tbz2") -> ArchiveFormat.BZIP2
        name.endsWith(".xz") || name.endsWith(".txz") -> ArchiveFormat.LZMA
        name.endsWith(".lzma") -> ArchiveFormat.LZMA
        name.endsWith(".zst") ->
            throw SevenZipException("Unsupported format: zst")
        else ->
            throw SevenZipException("Unknown archive format for file: ${file.name}")
    }
}

object SevenZipHelper {
    private val TAG = "METHOD_CHANNEL"
    fun extract(
        inputPath: String,
        outputPath: String,
        passwords: List<String>? = null,
        isCancelled: () -> Boolean,
        onProgress: (Double) -> Unit,
    ) {

        val inputFile = File(inputPath)
        val outDir = File(outputPath)
        if (!outDir.exists()) outDir.mkdirs()

        val format = detectArchiveFormat(inputFile)
        val attempts = mutableListOf<String?>()
        attempts.add(null)
        passwords?.let { attempts.addAll(it) }
        Log.e(TAG, "Passwords for this extraction $passwords")
        var lastError: Exception? = null

        for (password in attempts) {
            if (isCancelled()) return

            var archive: IInArchive? = null
            var inStream: RandomAccessFileInStream? = null

            try {
                val raf = RandomAccessFile(inputFile, "r")
                inStream = RandomAccessFileInStream(raf)

                var totalBytes: Long = 0
                var readBytes: Long = 0

                archive = SevenZip.openInArchive(
                    format,
                    inStream,
                    object : IArchiveOpenCallback, ICryptoGetTextPassword {

                        override fun cryptoGetTextPassword(): String {
                            return password ?: ""
                        }

                        override fun setTotal(files: Long?, bytes: Long?) {
                            totalBytes = bytes ?: 0
                        }

                        override fun setCompleted(files: Long?, bytes: Long?) {
                            if (isCancelled()) return
                            readBytes = bytes ?: 0

                            val p =
                                if (totalBytes > 0)
                                    (readBytes.toDouble() / totalBytes.toDouble()) * 50.0
                                else 0.0

                            onProgress(p.coerceIn(0.0, 50.0))
                        }
                    }
                )

                archive.extract(
                    null,
                    false,
                    object : IArchiveExtractCallback, ICryptoGetTextPassword {

                        var extractTotal: Long = 0

                        override fun cryptoGetTextPassword(): String {
                            return password ?: ""
                        }

                        override fun getStream(index: Int, mode: ExtractAskMode): ISequentialOutStream {

                            if (isCancelled()) throw SevenZipException("Cancelled")

                            val filePath = archive!!.getStringProperty(index, PropID.PATH)
                            val outFile = File(outDir, filePath)

                            if (mode != ExtractAskMode.EXTRACT) {
                                return ISequentialOutStream { data -> data.size }
                            }

                            if (!outFile.parentFile.exists()) outFile.parentFile.mkdirs()

                            return ISequentialOutStream { data ->
                                if (isCancelled()) throw SevenZipException("Cancelled")
                                outFile.appendBytes(data)
                                data.size
                            }
                        }

                        override fun prepareOperation(mode: ExtractAskMode) {}

                        override fun setOperationResult(result: ExtractOperationResult) {
                            if (result == ExtractOperationResult.WRONG_PASSWORD) {
                                throw SevenZipException("Wrong password")
                            }
                            if (result != ExtractOperationResult.OK && !isCancelled()) {
                                throw SevenZipException("Extraction error: $result")
                            }
                        }

                        override fun setTotal(total: Long) {
                            extractTotal = total
                        }

                        override fun setCompleted(complete: Long) {
                            if (isCancelled()) return

                            val percentExtraction =
                                if (extractTotal > 0)
                                    (complete.toDouble() / extractTotal.toDouble()) * 50.0
                                else 0.0

                            onProgress(50.0 + percentExtraction.coerceIn(0.0, 50.0))
                        }
                    }
                )

                if (!isCancelled()) {
                    onProgress(100.0)
                }

                archive.close()
                inStream.close()
                return

            } catch (e: SevenZipException) {
                lastError = e
            } finally {
                try { archive?.close() } catch (_: Exception) {}
                try { inStream?.close() } catch (_: Exception) {}
            }
        }

        throw SevenZipException("No valid password found. Last error: ${lastError?.message}")
    }
}
