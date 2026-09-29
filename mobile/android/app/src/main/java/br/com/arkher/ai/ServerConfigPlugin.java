package br.com.arkher.ai;

import android.content.Context;
import android.content.SharedPreferences;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/**
 * Guarda a URL do servidor de geração (Arkher AI) nas preferências do app.
 * O site (WebView) chama via window.Capacitor.Plugins.ServerConfig.
 */
@CapacitorPlugin(name = "ServerConfig")
public class ServerConfigPlugin extends Plugin {

    private static final String PREFS = "arkher_prefs";
    private static final String KEY_URL = "server_url";
    private static final String KEY_MODE = "mode"; // "server" | "offline"

    private SharedPreferences prefs() {
        return getContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    @PluginMethod
    public void getServerUrl(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("url", prefs().getString(KEY_URL, ""));
        ret.put("mode", prefs().getString(KEY_MODE, "server"));
        call.resolve(ret);
    }

    @PluginMethod
    public void setServerUrl(PluginCall call) {
        String url = call.getString("url", "");
        String mode = call.getString("mode", "server");
        prefs().edit().putString(KEY_URL, url).putString(KEY_MODE, mode).apply();
        JSObject ret = new JSObject();
        ret.put("ok", true);
        call.resolve(ret);
    }

    @PluginMethod
    public void getAppInfo(PluginCall call) {
        JSObject ret = new JSObject();
        try {
            ret.put("version", getContext().getPackageManager()
                    .getPackageInfo(getContext().getPackageName(), 0).versionName);
        } catch (Exception e) {
            ret.put("version", "1.0");
        }
        ret.put("platform", "android");
        ret.put("webview", "capacitor");
        call.resolve(ret);
    }
}
