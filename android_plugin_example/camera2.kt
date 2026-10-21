// the package will be generated at compiile time based on plugin name,
// so it doesn't matter what is in here
package IGNORED


import android.content.Context
import android.graphics.ImageFormat
import android.hardware.camera2.*
import android.hardware.camera2.params.OutputConfiguration
import android.hardware.camera2.params.SessionConfiguration
import android.media.Image
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import java.util.concurrent.Executors
import kotlin.arrayOf
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

// n.b. this must be called GodotAndroidPlugin for godot to find it
// (unless you change the template code that makes the plugin)
@OptIn(ExperimentalUnsignedTypes::class, ExperimentalStdlibApi::class)
class GodotAndroidPlugin(godot: Godot) : GodotPlugin(godot) {

    private val context: Context = godot.getActivity()!!.getApplicationContext()

    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    private val executor = Executors.newSingleThreadExecutor()
    private var latestRgbBytes: ByteArray? = null

    private var IMAGE_WIDTH: Int = 640
    private var IMAGE_HEIGHT: Int = 480

    private var selectedCameraId: String? = null

    private val imageSignalInfo =
            SignalInfo(
                    "OnImage",
                    Int::class.javaObjectType,
                    Int::class.javaObjectType,
                    ByteArray::class.java
            )

    override fun getPluginSignals(): Set<SignalInfo> {
        return setOf(imageSignalInfo)
    }

    override fun getPluginName() = BuildConfig.GODOT_PLUGIN_NAME

    @UsedByGodot
    fun startCamera() {
        Log.d("Camera2Plugin", "Starting camera")
        startBackgroundThread()
        imageReader = ImageReader.newInstance(IMAGE_WIDTH, IMAGE_HEIGHT, ImageFormat.YUV_420_888, 2)
        imageReader?.setOnImageAvailableListener(
                { reader ->
                    run {
                        val latestYUVImage: Image? = reader.acquireLatestImage()
                        if (latestYUVImage != null) {
                            hasNewImage = true
                            var width=latestYUVImage.width
                            var height=latestYUVImage.height
                            Log.d("Camera2Plugin", "New image available: $width $height")

                            val planes = latestYUVImage.planes
                            val yPlane = planes[0]
                            val uPlane = planes[1]
                            val vPlane = planes[2]

                            val yBuffer = yPlane.buffer
                            val uBuffer = uPlane.buffer
                            val vBuffer = vPlane.buffer

                            val ySize = yBuffer.remaining()
                            val uSize = uBuffer.remaining()
                            val vSize = vBuffer.remaining()

                            val yBytes = ByteArray(ySize)
                            val uBytes = ByteArray(uSize)
                            val vBytes = ByteArray(vSize)

                            yBuffer.get(yBytes)
                            uBuffer.get(uBytes)
                            vBuffer.get(vBytes)

                            val rgbSize = IMAGE_WIDTH * IMAGE_HEIGHT * 3
                            if (latestRgbBytes == null || latestRgbBytes!!.size != rgbSize) {
                                latestRgbBytes = ByteArray(rgbSize)
                            }

                            val yRowStride = yPlane.rowStride
                            val uRowStride = uPlane.rowStride
                            val vRowStride = vPlane.rowStride
                            val uPixelStride = uPlane.pixelStride
                            val vPixelStride = vPlane.pixelStride

                            var rgbIndex = 0
                            for (y in 0 until IMAGE_HEIGHT) {
                                val yRowOffset = y * yRowStride
                                val uvRowOffset = (y / 2) * uRowStride
                                for (x in 0 until IMAGE_WIDTH) {
                                    val yValue = yBytes[yRowOffset + x].toInt() and 0xFF
                                    val uValue =
                                            uBytes[uvRowOffset + (x / 2) * uPixelStride].toInt() and
                                                    0xFF
                                    val vValue =
                                            vBytes[uvRowOffset + (x / 2) * vPixelStride].toInt() and
                                                    0xFF

                                    val c = yValue - 16
                                    val d = uValue - 128
                                    val e = vValue - 128

                                    val r = ((298 * c + 409 * e + 128) shr 8).coerceIn(0, 255)
                                    val g =
                                            ((298 * c - 100 * d - 208 * e + 128) shr 8).coerceIn(
                                                    0,
                                                    255
                                            )
                                    val b = ((298 * c + 516 * d + 128) shr 8).coerceIn(0, 255)

                                    latestRgbBytes!![rgbIndex++] = r.toByte()
                                    latestRgbBytes!![rgbIndex++] = g.toByte()
                                    latestRgbBytes!![rgbIndex++] = b.toByte()
                                }
                            }
                            latestYUVImage.close()
                            emitSignal(
                                    imageSignalInfo.name,
                                    IMAGE_WIDTH,
                                    IMAGE_HEIGHT,
                                    latestRgbBytes
                            )
                        }
                    }
                },
                backgroundHandler
        )

        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val cameraId = findCameraIdByIndex(cameraManager, 0)
        if (cameraId == null) {
            Log.e("Camera2Plugin", "No camera found at index 0")
            return
        }
        selectedCameraId = cameraId
        cameraManager.openCamera(
                cameraId,
                executor,
                object : CameraDevice.StateCallback() {
                    override fun onOpened(camera: CameraDevice) {
                        Log.d("Camera2Plugin", "Camera opened {$cameraId}")
                        cameraDevice = camera
                        createCameraCaptureSession()
                    }

                    override fun onDisconnected(camera: CameraDevice) {
                        Log.d("Camera2Plugin", "Camera disconnected {$cameraId}")
                        camera.close()
                        cameraDevice = null
                    }

                    override fun onError(camera: CameraDevice, error: Int) {
                        Log.d("Camera2Plugin", "Camera error {$cameraId} $error")
                        camera.close()
                        cameraDevice = null
                    }
                }
        )
    }

    private fun findCameraIdByIndex(cameraManager: CameraManager, index: Int): String? {

        var count: Int = 0
        for (id in cameraManager.cameraIdList) {
            if (count == index) {
                return id
            }
            count = count + 1
            /*            val characteristics = cameraManager.getCameraCharacteristics(id)
            val pos =
                    characteristics.get(
                            CameraCharacteristics.Key(
                                    "com.meta.extra_metadata.position",
                                    Int::class.java
                            )
                    )
            if (pos == position) {
                return id
            }*/
        }
        return null
    }

    private fun createCameraCaptureSession() {

        val outputList = buildList { add(OutputConfiguration(imageReader!!.surface)) }

        val config: SessionConfiguration =
                SessionConfiguration(
                        SessionConfiguration.SESSION_REGULAR,
                        outputList,
                        executor,
                        object : CameraCaptureSession.StateCallback() {
                            override fun onConfigured(session: CameraCaptureSession) {
                                Log.d("Camera2Plugin", "Capture session configured")
                                captureSession = session
                                val captureRequestBuilder =
                                        cameraDevice!!.createCaptureRequest(
                                                CameraDevice.TEMPLATE_PREVIEW
                                        )
                                captureRequestBuilder.addTarget(imageReader!!.surface)
                                session.setRepeatingRequest(
                                        captureRequestBuilder.build(),
                                        null,
                                        null
                                )
                            }
                            override fun onConfigureFailed(session: CameraCaptureSession) {
                                Log.e("Camera2Plugin", "Capture session configuration failed")
                            }
                        }
                )

        cameraDevice!!.createCaptureSession(config)
    }

    fun stopCamera() {
        captureSession?.close()
        cameraDevice?.close()
        imageReader?.close()
        stopBackgroundThread()
    }

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
    }
    @Volatile private var hasNewImage: Boolean = false

    init {
        // Ensure hasNewImage is false at start
        hasNewImage = false
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        backgroundThread?.join()
        backgroundThread = null
        backgroundHandler = null
    }

    val cameraPermission = android.Manifest.permission.CAMERA

    var allPermissions = arrayOf(cameraPermission)

    @UsedByGodot
    fun hasCameraPermission(): Boolean {
        val pm = context.packageManager
        var granted = true
        allPermissions.forEach({
            if (context.checkSelfPermission(it) !=
                            android.content.pm.PackageManager.PERMISSION_GRANTED
            ) {
                granted = false
            }
        })
        Log.d("Camera2Plugin", "Permissions granted: ${granted}")
        return granted
    }

    @UsedByGodot
    fun requestCameraPermission() {
        
        Log.d("Camera2Plugin", "Request permission")
        getActivity()?.requestPermissions(allPermissions, 0)
    }
}
