// Utils only used in the extension. Do not import this file in the preferences window because Shell is not available there.

import GLib from "gi://GLib";
import Soup from "gi://Soup";
import Shell from "gi://Shell";
import Gio from "gi://Gio";
import { errorLog } from "./common.js";

Gio._promisify(Gio.DBusProxy, "new", "new_finish");
Gio._promisify(Gio.File.prototype, "replace_contents_bytes_async", "replace_contents_finish");
Gio._promisify(Gio.File.prototype, "read_async", "read_finish");
Gio._promisify(Soup.Session.prototype, "send_and_read_async", "send_and_read_finish");

// TODO: sort this out

/**
 * @param {string} id
 * @param {string} entry
 * @param {string} [busName]
 * @returns {Gio.AppInfo | null}
 */
export const getAppInfoByIdAndEntry = (id, entry, busName) => {
    const candidates = [];
    if (entry) {
        candidates.push(`${entry}.desktop`, entry);
    }
    if (id) {
        candidates.push(`${id}.desktop`, id, `${id.toLowerCase()}.desktop`, id.toLowerCase());
    }
    if (busName) {
        const parts = busName.split(".");
        const mprisIdx = parts.indexOf("MediaPlayer2");
        if (mprisIdx !== -1 && parts[mprisIdx + 1]) {
            const raw = parts[mprisIdx + 1];
            candidates.push(`${raw}.desktop`, raw);
        }
    }

    const lowerId = (id || "").toLowerCase();
    const lowerBus = (busName || "").toLowerCase();
    if (lowerId.includes("chrome") || lowerId.includes("chromium") || lowerBus.includes("chrome") || lowerBus.includes("chromium")) {
        candidates.push("google-chrome.desktop", "google-chrome-stable.desktop", "chromium.desktop", "com.google.Chrome.desktop");
    } else if (lowerId.includes("firefox") || lowerBus.includes("firefox")) {
        candidates.push("firefox.desktop", "org.mozilla.firefox.desktop");
    } else if (lowerId.includes("spotify") || lowerBus.includes("spotify")) {
        candidates.push("spotify.desktop", "com.spotify.Client.desktop");
    } else if (lowerId.includes("brave") || lowerBus.includes("brave")) {
        candidates.push("brave-browser.desktop", "brave.desktop");
    } else if (lowerId.includes("edge") || lowerBus.includes("edge")) {
        candidates.push("microsoft-edge.desktop");
    }

    const apps = Gio.AppInfo.get_all();
    for (const cand of candidates) {
        const cleanCand = cand.replace(/\.desktop$/, "").toLowerCase();
        for (const app of apps) {
            const aid = (app.get_id() || "").toLowerCase();
            const aname = (app.get_name() || "").toLowerCase();
            const aexec = (app.get_executable() || "").toLowerCase();
            const adisp = (app.get_display_name() || "").toLowerCase();
            if (
                aid === cand.toLowerCase() ||
                aid === `${cleanCand}.desktop` ||
                aname === cleanCand ||
                adisp === cleanCand ||
                (cleanCand.length > 3 && aexec.includes(cleanCand))
            ) {
                return app;
            }
        }
    }
    return null;
};

/**
 * @param {string} id
 * @param {string} entry
 * @param {string} [busName]
 * @returns {Shell.App | null}
 */
export const getAppByIdAndEntry = (id, entry, busName) => {
    const appSystem = Shell.AppSystem.get_default();
    const runningApps = appSystem.get_running();
    const idResults = Shell.AppSystem.search(id ?? "");
    const entryResults = Shell.AppSystem.search(entry ?? "");

    // Try to find in running apps first
    if (entryResults?.length > 0) {
        const app = runningApps.find((app) => entryResults[0].includes(app.get_id()));
        if (app != null) {
            return app;
        }
    }
    if (idResults?.length > 0) {
        const app = runningApps.find((app) => idResults[0].includes(app.get_id()));
        if (app != null) {
            return app;
        }
    }

    const candidates = [];
    if (entry) {
        candidates.push(`${entry}.desktop`, entry);
    }
    if (id) {
        candidates.push(`${id}.desktop`, id, `${id.toLowerCase()}.desktop`, id.toLowerCase());
    }
    if (busName) {
        const parts = busName.split(".");
        const mprisIdx = parts.indexOf("MediaPlayer2");
        if (mprisIdx !== -1 && parts[mprisIdx + 1]) {
            const raw = parts[mprisIdx + 1];
            candidates.push(`${raw}.desktop`, raw);
        }
    }

    const lowerId = (id || "").toLowerCase();
    const lowerBus = (busName || "").toLowerCase();
    if (lowerId.includes("chrome") || lowerId.includes("chromium") || lowerBus.includes("chrome") || lowerBus.includes("chromium")) {
        candidates.push("google-chrome.desktop", "google-chrome-stable.desktop", "chromium.desktop", "com.google.Chrome.desktop");
    } else if (lowerId.includes("firefox") || lowerBus.includes("firefox")) {
        candidates.push("firefox.desktop", "org.mozilla.firefox.desktop");
    } else if (lowerId.includes("spotify") || lowerBus.includes("spotify")) {
        candidates.push("spotify.desktop", "com.spotify.Client.desktop");
    } else if (lowerId.includes("brave") || lowerBus.includes("brave")) {
        candidates.push("brave-browser.desktop", "brave.desktop");
    } else if (lowerId.includes("edge") || lowerBus.includes("edge")) {
        candidates.push("microsoft-edge.desktop");
    }

    for (const cand of candidates) {
        let app = appSystem.lookup_app(cand);
        if (app != null) {
            return app;
        }
        app = runningApps.find((a) => a.get_id() === cand || a.get_id() === `${cand}.desktop`);
        if (app != null) {
            return app;
        }
    }

    // Fallback using getAppInfoByIdAndEntry
    const appInfo = getAppInfoByIdAndEntry(id, entry, busName);
    if (appInfo != null) {
        const app = appSystem.lookup_app(appInfo.get_id());
        if (app != null) {
            return app;
        }
    }

    return null;
};

/**
 * @param {string} url
 * @returns {Promise<Gio.InputStream>}
 */
export const getImage = async (url) => {
    if (url == null || url == "") {
        return null;
    }
    const encoder = new TextEncoder();
    const urlBytes = encoder.encode(url);
    const encodedUrl = GLib.base64_encode(urlBytes);
    const path = GLib.build_filenamev([GLib.get_user_cache_dir(), "mediacontrols@cliffniff.github.com", encodedUrl]);
    const exitCode = GLib.mkdir_with_parents(GLib.path_get_dirname(path), 493);
    if (exitCode === -1) {
        errorLog(`Failed to create cache directory: ${path}`);
        return null;
    }
    const file = Gio.File.new_for_path(path);
    if (file.query_exists(null)) {
        const stream = await file.read_async(null, null).catch(errorLog);
        if (stream == null) {
            errorLog(`Failed to load image from cache: ${encodedUrl}`);
            return null;
        }
        return stream;
    } else {
        const uri = GLib.Uri.parse(url, GLib.UriFlags.NONE);
        if (uri == null) {
            return null;
        }
        const scheme = uri.get_scheme();
        if (scheme === "file") {
            const file = Gio.File.new_for_uri(uri.to_string());
            if (file.query_exists(null) === false) {
                return null;
            }
            const stream = await file.read_async(null, null).catch(errorLog);
            if (stream == null) {
                errorLog(`Failed to load local image: ${encodedUrl}`);
                return null;
            }
            return stream;
        } else if (scheme === "http" || scheme === "https") {
            const session = new Soup.Session();
            const message = new Soup.Message({ method: "GET", uri });
            const bytes = await session.send_and_read_async(message, null, null).catch(errorLog);
            if (bytes == null) {
                errorLog(`Failed to load image: ${url}`);
                return null;
            }
            // @ts-expect-error Types are wrong
            const resultPromise = file.replace_contents_bytes_async(bytes, null, false, Gio.FileCreateFlags.NONE, null);
            const result = await resultPromise.catch(errorLog);
            if (result?.[0] === false) {
                errorLog(`Failed to cache image: ${url}`);
                return null;
            }
            const stream = await file.read_async(null, null).catch(errorLog);
            if (stream == null) {
                errorLog(`Failed to load cached image: ${url}`);
                return null;
            }
            return stream;
        } else {
            errorLog(`Invalid scheme: ${scheme}`);
            return null;
        }
    }
};

/**
 * @template T
 * @param {Gio.DBusInterfaceInfo} ifaceInfo
 * @param {string} name
 * @param {string} object
 * @returns {Promise<T>}
 */
export const createDbusProxy = async (ifaceInfo, name, object) => {
    // @ts-expect-error Types have not been promisified yet
    const proxy = Gio.DBusProxy.new(
        Gio.DBus.session,
        Gio.DBusProxyFlags.NONE,
        ifaceInfo,
        name,
        object,
        ifaceInfo.name,
        null,
    );
    return proxy;
};
