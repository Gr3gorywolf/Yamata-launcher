package com.gr3gorywolf.yamata_launcher


import android.content.Context
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.content.FileProvider
import androidx.core.content.ContextCompat
import android.os.Environment
import java.io.File
import com.gr3gorywolf.yamata_launcher.utils.ZipUtils
import com.gr3gorywolf.yamata_launcher.utils.SevenZipHelper
import android.content.Intent
import android.net.Uri
import android.os.PowerManager

class MainActivity : FlutterActivity() {

    private val CHANNEL = "yamata.launcher/methods"
    private val TAG = "METHOD_CHANNEL"

    private var initialized = false
    private var baseName = "yamata"
    private var aria2cDirName = "aria2c"
    private var aria2cBinFile = "libaria2c.so"
    private var lib7zaBinFile = "libp7zip.so"
    private var utilsName = "libutils.zip.so"
    private var certFileName = "libutils.so/yamata_launcher.pem"
    private var certKeyFileName = "libutils.so/yamata_launcher.key"
    private val extractTasks = mutableMapOf<String, Boolean>()
    


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "MyApp:DownloadLock"
        )
       val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )
        channel.setMethodCallHandler { call, result ->

            when (call.method) {
                 "extractArchive" -> {
                    try {
                        val input = call.argument<String>("inputPath")!!
                        val output = call.argument<String>("outputPath")!!
                        val taskId = call.argument<String>("taskId")!!
                        val passwords = call.argument<List<String>>("passwords")!!
                         extractTasks[taskId] = false
                           Log.e(TAG, "Starting extraction thread for taskId: $taskId") 
                      Thread {
                        try {
                            Log.e(TAG, "Starting extraction for taskId: $taskId")
                            SevenZipHelper.extract(
                                input,
                                output,
                                passwords,
                                isCancelled = { extractTasks[taskId] == true }
                            ) { progress ->

                                if (extractTasks[taskId] == true) return@extract
                                Log.e(TAG, "Extraction progress: $progress")
                                runOnUiThread {
                                    channel.invokeMethod(
                                        "extractProgress",
                                        mapOf(
                                            "progress" to progress,
                                            "taskId" to taskId
                                        )
                                    )
                                }
                            }
                            Log.e(TAG, "Extraction completed")
                            runOnUiThread {
                                channel.invokeMethod(
                                    "extractCompleted",
                                    mapOf("taskId" to taskId)
                                )
                            }

                        } catch (e: Exception) {
                            Log.e(TAG, "Extraction error", e)
                            runOnUiThread {
                                channel.invokeMethod(
                                    "extractError",
                                    mapOf(
                                        "taskId" to taskId,
                                        "message" to (e.message ?: "Unknown error")
                                    )
                                )
                            }

                        } finally {
                            extractTasks.remove(taskId)
                        }
                    }.start()
                    result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to extract archive", e)
                        result.error("ARGUMENT_ERROR", e.message, null)
                    }
                }

                "cancelExtract" -> {
                    val taskId = call.argument<String>("taskId")!!
                    extractTasks[taskId] = true
                    result.success(true)
                }
                "getIntentUriFromFile" -> {
                    try {
                        val path = call.argument<String>("path")!!
                        val file = File(path)
                        val uri = FileProvider.getUriForFile(
                        this,
                        "${applicationContext.packageName}.fileProvider",
                        file
                    )
                        result.success(uri.toString())
                    } catch (e: Exception) {
                        result.error("Failed to get intentUri", e.message, null)
                    }
                }

                "grantUriPermission" -> {
                    try {
                        val uriString = call.argument<String>("uri")
                        val packageName = call.argument<String>("packageName")

                        require(!uriString.isNullOrBlank()) { "uri is null or empty" }
                        require(!packageName.isNullOrBlank()) { "packageName is null or empty" }

                        val uri = Uri.parse(uriString)

                        applicationContext.grantUriPermission(
                            packageName,
                            uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION
                        )

                        result.success(true)

                    } catch (e: Exception) {
                        result.error(
                            "GRANT_URI_PERMISSION_FAILED",
                            e.message,
                            null
                        )
                    }
                }

                "getSystemPaths" -> {
                    try {
                     val context = applicationContext
                    val internalPath = Environment.getExternalStorageDirectory().absolutePath

                    val externalDirs = ContextCompat.getExternalFilesDirs(context, null)

                    val externalSdCardPath = externalDirs
                        .drop(1)
                        .firstOrNull()
                        ?.absolutePath
                        ?.let { path ->
                            val cutIndex = path.indexOf("/Android/")
                            if (cutIndex != -1) path.substring(0, cutIndex) else path
                        }

                    val downloadsPath =
                        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                            ?.absolutePath

                    val documentsPath =
                        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
                            ?.absolutePath

                    val paths = mapOf(
                        "internalPath" to internalPath,
                        "externalSdCardPath" to externalSdCardPath,
                        "downloadsPath" to downloadsPath,
                        "documentsPath" to documentsPath
                    )

                    result.success(paths)
                    } catch (e: Exception) {
                        result.error("PATHS_ERROR", e.message, null)
                    }
                }

                "setWakeLock" -> {
                    try {
                        val shouldAcquire = call.argument<Boolean>("shouldAcquire") ?: false
                        if (shouldAcquire) {
                            if (!wakeLock.isHeld) {
                                wakeLock.acquire()
                            }
                        } else {
                            if (wakeLock.isHeld) {
                                wakeLock.release()
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WAKELOCK_ERROR", e.message, null)
                    }
                }

                "initAria2c" -> {
                    try {
                       val paths = initAria2c(applicationContext)
                        result.success(paths)
                    } catch (e: Exception) {
                        result.error("INIT_ERROR", e.message, null)
                    }
                }
            }
        }
    }

    /**
     * Extract aria2c into app private storage (noBackupFilesDir)
     */
   private fun initAria2c(context: Context): Map<String, String> {

    if (initialized) {
        val baseDir = File(context.noBackupFilesDir, baseName)
        val certFile = File(baseDir, certFileName)
        val binaryFile = File(context.applicationInfo.nativeLibraryDir, aria2cBinFile)

        return mapOf(
            "certPath" to certFile.absolutePath,
            "binaryPath" to binaryFile.absolutePath
        )
    }

    val baseDir = File(context.noBackupFilesDir, baseName)
    baseDir.mkdirs()

    val certFile = File(baseDir, certFileName)
    val utilsFile = File(context.applicationInfo.nativeLibraryDir, utilsName)

    if (!utilsFile.exists()) {
        Log.e(TAG, "$utilsName NOT FOUND")
        throw Exception("$utilsName not found")
    }

    if (!certFile.exists()) {
        Log.d(TAG, "Unzipping utils…")
        ZipUtils.unzip(utilsFile, baseDir)
    }

    baseDir.walk().forEach { file ->
        Log.d(TAG, "Loading: ${file.absolutePath}")
    }

    initialized = true
    val binaryFile = File(context.applicationInfo.nativeLibraryDir, aria2cBinFile)
    return mapOf(
        "certPath" to certFile.absolutePath,
        "binaryPath" to binaryFile.absolutePath
    )
}
}
