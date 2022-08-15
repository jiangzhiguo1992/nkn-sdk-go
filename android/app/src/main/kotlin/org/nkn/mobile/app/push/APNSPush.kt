package org.nkn.mobile.app.push

import android.content.res.AssetManager
import android.util.Log
import com.clevertap.apns.ApnsClient
import com.clevertap.apns.Notification
import com.clevertap.apns.NotificationResponse
import com.clevertap.apns.NotificationResponseListener
import com.clevertap.apns.clients.ApnsClientBuilder
import io.sentry.Sentry
import org.json.JSONException
import org.json.JSONObject
import java.util.*

/**
 * Created by JZG on 2021/6/28.
 */
class APNSPush {
    companion object {
        private const val ApnsTopic = "com.xxx.xxx"
        private const val ApnsAssetsPath = "ApnsFilePath"
        private const val ApnsPassword = "ApnsFilePwd"

        private var apnsClient: ApnsClient? = null

        fun openClient(assetManager: AssetManager) {
            try {
                val inputStream = assetManager.open(ApnsAssetsPath)
                apnsClient = ApnsClientBuilder()
                    .withProductionGateway()
                    .inAsynchronousMode()
                    .withCertificate(inputStream)
                    .withPassword(ApnsPassword)
                    .withDefaultTopic(ApnsTopic)
                    .build()
            } catch (e: Exception) {
                Log.i("SendPush", "openClient: ${e.message}")
                e.printStackTrace()
            }
        }

        fun closeClient() {
            Log.i("SendPush", "closeClient")
            // apnsClient?.cose()
        }

        fun push(assetManager: AssetManager, uuid: String, deviceToken: String, pushPayload: String) {
            if (apnsClient == null) {
                openClient(assetManager)
            }
            val rootMap = getMap(pushPayload, null) ?: mapOf()

            val apsJson = rootMap["aps"] as? JSONObject
            val apsMap = getMap("{}", apsJson) ?: mapOf()

            val badge = (apsMap["badge"] as? Int) ?: -1
            val sound = (apsMap["sound"] as? String) ?: ""

            val alertJson = apsMap["alert"] as? JSONObject
            val alertMap = getMap("{}", alertJson) ?: mapOf()
            val title = (alertMap["title"] as? String) ?: ""
            val body = (alertMap["body"] as? String) ?: ""

            val builder = Notification.Builder(deviceToken)
                .alertTitle(title)
                .alertBody(body)
                .sound(sound)
            if (badge >= 0) {
                builder.badge(badge)
            }
            builder.uuid(UUID.fromString(uuid))
                .customField("apns-push-type", "alert")
                .expiration(-1)
                .priority(Notification.Priority.IMMEDIATE)
                .topic(ApnsTopic)
            val n: Notification = builder.build()
            apnsClient?.push(n, object : NotificationResponseListener {
                override fun onSuccess(notification: Notification?) {
                    Log.d("SendPush", "push - success - deviceToken:$deviceToken")
                }

                override fun onFailure(notification: Notification?, nr: NotificationResponse) {
                    Log.e("SendPush", "push - fail - deviceToken:$deviceToken - response:$nr")
                    Sentry.captureException(nr.cause)
                }
            })
        }

        private fun getMap(jsonString: String, jb: JSONObject?): HashMap<String, Any>? {
            val jsonObject: JSONObject
            try {
                jsonObject = jb ?: JSONObject(jsonString)
                val keyIter: Iterator<String> = jsonObject.keys()
                var key: String
                var value: Any
                val valueMap = HashMap<String, Any>()
                while (keyIter.hasNext()) {
                    key = keyIter.next()
                    value = jsonObject[key] as Any
                    valueMap[key] = value
                }
                return valueMap
            } catch (e: JSONException) {
                e.printStackTrace()
            }
            return null
        }

    }
}