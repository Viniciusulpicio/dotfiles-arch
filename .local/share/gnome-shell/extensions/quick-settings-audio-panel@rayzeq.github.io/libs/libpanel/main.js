import GLib from "gi://GLib";
import GObject from "gi://GObject";
import { InjectionManager } from "resource:///org/gnome/shell/extensions/extension.js";
import { EventEmitter } from "resource:///org/gnome/shell/misc/signals.js";
import * as Main from "resource:///org/gnome/shell/ui/main.js";
import { QuickSettingsMenu, } from "resource:///org/gnome/shell/ui/quickSettings.js";
import PanelGridMenu from "./menu.js";
import Panel from "./panel.js";
import { current_extension_uuid, get_settings, rsplit, split } from "./utils.js";
export { Panel };
export const VERSION = 2;
// Patching the default menu to have the exact same API as the one from `Panel`.
// This way, extensions can use them the same way.
QuickSettingsMenu.prototype.getItems = function () {
    return this._grid
        .get_children()
        .filter(item => item !== this._grid.layout_manager._overlay);
};
QuickSettingsMenu.prototype.removeItem = function (item) {
    this._grid.remove_child(item);
    if ("menu" in item && item.menu) {
        for (const id of item.menu._signalConnectionsByName?.["open-state-changed"] || []) {
            // biome-ignore lint/style/noNonNullAssertion: if it has _signalConnectionsByName["open-state-changed"], it has _signalConnections
            if (item.menu._signalConnections[id].callback.toString().includes("this._setDimmed")) {
                item.menu.disconnect(id);
            }
        }
        this._overlay.remove_child(item.menu.actor);
    }
};
QuickSettingsMenu.prototype.getColumnSpan = function (item) {
    const value = new GObject.Value();
    this._grid.layout_manager.child_get_property(this._grid, item, "column-span", value);
    const column_span = value.get_int();
    value.unset();
    return column_span;
};
QuickSettingsMenu.prototype.setColumnSpan = function (item, column_span) {
    this._grid.layout_manager.child_set_property(this._grid, item, "column-span", column_span);
};
export class LibPanel extends EventEmitter {
    static get_instance() {
        return Main.panel._libpanel;
    }
    static get VERSION() {
        return LibPanel.get_instance()?.VERSION || VERSION;
    }
    static get main_panel() {
        // biome-ignore lint/style/noNonNullAssertion: should always be defined by this point
        return LibPanel.get_instance()?.main_panel || Main.panel.statusArea.quickSettings.menu;
    }
    static get enablers() {
        return LibPanel.get_instance()?.enablers || [];
    }
    static get enabled() {
        return LibPanel.enablers.length !== 0;
    }
    static async enable() {
        const uuid = current_extension_uuid();
        if (!uuid) {
            console.error("[LibPanel] libpanel wasn't directly enabled from extension code. It will not be enabled.");
            return;
        }
        let instance = LibPanel.get_instance();
        // DO NOT TRUST THE WARNING: typescript still doesn't support async constructors after 7 years..., nor does it support @ts-expect-warning
        if (!instance)
            instance = Main.panel._libpanel = await new LibPanel();
        if (instance.VERSION !== VERSION)
            console.warn(`[LibPanel] ${current_extension_uuid()} depends on libpanel ${VERSION} but libpanel ${instance.VERSION} is loaded`);
        if (instance.enablers.indexOf(uuid) < 0)
            instance.enablers.push(uuid);
    }
    static disable() {
        const instance = LibPanel.get_instance();
        if (!instance)
            return;
        const uuid = current_extension_uuid();
        if (!uuid) {
            console.error("[LibPanel] libpanel wasn't directly disabled from extension code. It will not be disabled.");
            return;
        }
        const index = instance.enablers.indexOf(uuid);
        if (index > -1)
            instance.enablers.splice(index, 1);
        if (instance.enablers.length === 0) {
            instance.destroy();
            delete Main.panel._libpanel;
        }
    }
    static add_panel(panel) {
        const instance = LibPanel.get_instance();
        if (!instance) {
            console.error(`[LibPanel] ${current_extension_uuid()} tried to add a panel, but the library is disabled.`);
            return;
        }
        instance.add_panel(panel);
    }
    static remove_panel(panel) {
        panel.get_parent()?.remove_child(panel);
    }
    static _get_grid(monitor) {
        const instance = LibPanel.get_instance();
        if (!instance) {
            console.error("No instance while doing drag & drop, this is a bug");
            return;
        }
        const dtp_monitor = instance.dash_to_panel_settings?.availableMonitors[monitor];
        const monitor_name = dtp_monitor && !dtp_monitor.primary ? dtp_monitor.id : "primary";
        return instance.grids.get(monitor_name);
    }
    // This doesn't actually move anything, it just affects the saved layout
    static _move_panel(panel, monitor, column, row) {
        const instance = LibPanel.get_instance();
        if (!instance) {
            console.error("No instance while doing drag & drop, this is a bug");
            return;
        }
        const layout = instance.get_layout();
        const previous_location = layout.get(panel.panel_id);
        layout.delete(panel.panel_id);
        if (previous_location) {
            for (const location of layout.values()) {
                if (location[0] === previous_location[0] &&
                    location[1] === previous_location[1] &&
                    location[2] > previous_location[2]) {
                    location[2] -= 1;
                }
            }
        }
        for (const location of layout.values()) {
            if (location[0] === monitor && location[1] === column && location[2] >= row) {
                location[2] += 1;
            }
        }
        layout.set(panel.panel_id, [monitor, column, row]);
        instance.save_layout(layout);
    }
    VERSION = VERSION;
    enablers;
    injection_manager;
    settings;
    // @ts-expect-error: typescript still doesn't support async constructors after 7 years...
    main_panel;
    grids;
    dash_to_panel;
    dash_to_panel_settings;
    constructor() {
        super();
        this.enablers = [];
        this.injection_manager = new InjectionManager();
        const this_path = `/${split(rsplit(import.meta.url, "/", 1)[0], "/", 3)[3]}`;
        this.settings = get_settings(`${this_path}/org.gnome.shell.extensions.libpanel.gschema.xml`);
        this.injection_manager.overrideMethod(
        // biome-ignore lint/style/noNonNullAssertion: this should always be set
        Main.panel.statusArea.quickSettings.constructor.prototype, "_setupIndicators", wrapped => function () {
            const promise = wrapped.call(this);
            // @ts-expect-error: hack
            this.__setup_promise = promise.then(() => delete this.__setup_promise);
            return promise;
        });
        this.grids = new Map();
        // @ts-expect-error: typescript still doesn't support async constructors after 7 years...
        // biome-ignore lint/correctness/noConstructorReturn: this is an async constructor
        return (async () => {
            this.main_panel = await this.patch_menu(Main.panel, "primary");
            const patch_dtp_panels = async (panels) => {
                const qsap_panels = [...this.grids.values()].flatMap(panel_grid => panel_grid.remove_all_panels());
                for (const panel of panels) {
                    await this.patch_menu(panel, 
                    // biome-ignore lint/style/noNonNullAssertion: if we're here, dash-to-panel is loaded
                    this.dash_to_panel_settings.availableMonitors[panel.monitor.index].id);
                }
                for (const panel of qsap_panels) {
                    this.add_panel(panel);
                }
            };
            const patch_dash_to_panel = async () => {
                this.dash_to_panel ??= Main.extensionManager.lookup("dash-to-panel@jderose9.github.com");
                if (this.dash_to_panel) {
                    this.dash_to_panel_settings ??= await import(this.dash_to_panel.dir.get_child("panelSettings.js").get_uri());
                }
                if (global.dashToPanel) {
                    // dash-to-panel is already initialized, patch it now
                    if (global.dashToPanel.panels) {
                        await patch_dtp_panels(global.dashToPanel.panels);
                    }
                    // This event will be sent if dash-to-panel wasn't initialized yet,
                    // and when a monitors changes (added or deleted)
                    global.dashToPanel.connect_object("panels-created", async () => {
                        // biome-ignore lint/style/noNonNullAssertion: those properties are guaranteed to exist when the signal is sent
                        await patch_dtp_panels(global.dashToPanel.panels);
                        return false;
                    }, this);
                }
            };
            await patch_dash_to_panel();
            Main.extensionManager.connect_object("extension-state-changed", (_, extension) => {
                if (extension.uuid === "dash-to-panel@jderose9.github.com" && extension.enabled) {
                    patch_dash_to_panel().catch(e => console.error(e));
                }
                return false;
            }, this);
            return this;
        })().catch(e => console.error(e));
    }
    destroy() {
        if (global.dashToPanel)
            global.dashToPanel.disconnect_object(this);
        Main.extensionManager.disconnect_object(this);
        this.injection_manager.clear();
        this.grids.clear();
        // Unpatch all panels
        this.emit("destroy");
        this.disconnectAll();
    }
    async patch_menu(panel, monitor_name) {
        // biome-ignore lint/style/noNonNullAssertion: this should always be set
        const quickSettings = panel.statusArea.quickSettings;
        const menu = quickSettings.menu;
        // prevent double-patch
        // @ts-expect-error: menu isn't supposed to be anything else than QuickSettingsMenu
        if (!(menu instanceof QuickSettingsMenu))
            return menu.box.default_panel;
        const gnome_panel = new Panel("", 2);
        // setting the id after so it's not: `quick-settings-audio-panel@rayzeq.github.io/gnome-shell/main:primary`
        gnome_panel.panel_id = `gnome-shell/main:${monitor_name}`;
        const grid = new PanelGridMenu(menu.sourceActor, menu._arrowAlignment, menu._arrowSide, gnome_panel, this.settings, monitor_name);
        this.grids.set(monitor_name, grid);
        grid.setArrowOrigin(menu._boxPointer._arrowOrigin);
        grid.setSourceAlignment(menu._boxPointer._sourceAlignment);
        // set properties other extensions might expect
        // @ts-expect-error
        grid._dimEffect = gnome_panel._dimEffect;
        // @ts-expect-error
        grid._grid = gnome_panel._grid;
        // @ts-expect-error
        grid._overlay = gnome_panel._overlay;
        // @ts-expect-error
        grid._setDimmed = gnome_panel._setDimmed.bind(gnome_panel);
        // @ts-expect-error
        grid.getFirstItem = gnome_panel.getFirstItem.bind(gnome_panel);
        // @ts-expect-error
        grid.addItem = gnome_panel.addItem.bind(gnome_panel);
        // @ts-expect-error
        grid.insertItemBefore = gnome_panel.insertItemBefore.bind(gnome_panel);
        // @ts-expect-error
        grid._completeAddItem = gnome_panel._completeAddItem.bind(gnome_panel);
        // the menu is initialized in an async function, we need to wait for it to finish,
        // otherwise we risk patching it midway and breaking everything.
        // note that it is only necessary when dash-to-panel is enabled after QSAP,
        // because we patch the menus it creates instantly after their creation
        // @ts-expect-error: hack
        if (quickSettings.__setup_promise)
            await quickSettings.__setup_promise;
        const old_menu = this.replace_menu(panel, quickSettings, grid);
        this.move_quick_settings(old_menu, gnome_panel);
        this.add_panel(gnome_panel, [monitor_name, 0, 0]);
        const handler_id = this.connect("destroy", () => {
            old_menu.disconnect_object(this);
            panel.disconnect_object(this);
            this.move_quick_settings(gnome_panel, old_menu);
            this.replace_menu(panel, quickSettings, old_menu);
            grid.destroy();
            return false;
        });
        old_menu.connect_object("destroy", () => {
            this.disconnect(handler_id);
        }, this);
        // Dash-to-panel caches menus (even between extension restarts), so they're never
        // destroyed, however the panel are destroyed.
        // It's not really worth unpatching the menu, so we just destroy it.
        panel.connect_object("destroy", async () => {
            this.disconnect(handler_id);
            old_menu.disconnect_object(this);
            this.grids.delete(monitor_name);
            for (const panel of grid.remove_all_panels()) {
                this.add_panel(panel);
            }
            try {
                if (!this.dash_to_panel)
                    return;
                const dash_to_panel = await import(this.dash_to_panel.dir.get_child("extension.js").get_uri());
                // Dash-to-panel is installed but wasn't ever enabled
                if (!dash_to_panel.PERSISTENTSTORAGE)
                    return;
                // Gnome shell is being shut down, don't do anything
                if (gnome_panel.is_destroyed && monitor_name === "primary")
                    return;
                const index = dash_to_panel.PERSISTENTSTORAGE.quickSettings.indexOf(grid);
                this.move_quick_settings(gnome_panel, old_menu);
                this.replace_menu(null, quickSettings, old_menu);
                grid.destroy();
                dash_to_panel.PERSISTENTSTORAGE.quickSettings[index] = old_menu;
            }
            catch (e) {
                console.error(e);
            }
        }, this);
        return gnome_panel;
    }
    replace_menu(panel, quick_settings, new_menu) {
        const old_menu = quick_settings.menu;
        if (panel) {
            // undo changes done by `Panel._onMenuSet`
            // @ts-expect-error: PanelGridMenu is invalid because we override some of its properties
            panel.menuManager.removeMenu(old_menu);
            // @ts-expect-error: property set by `Panel`
            delete old_menu._openChangedConnected;
            old_menu.disconnect_object(panel);
        }
        // undo changes done by `PanelMenuButton.setMenu`
        old_menu.actor.remove_style_class_name("panel-menu");
        // there should be only one id, but let's be careful
        for (const id of old_menu._signalConnectionsByName?.["open-state-changed"] || [])
            old_menu.disconnect(id);
        // let's hope there wasn't any other action
        old_menu.actor.clear_actions();
        Main.layoutManager.uiGroup.remove_child(old_menu.actor);
        // undo changes done by `QuickSettingsMenu`
        Main.layoutManager.disconnect_object(old_menu);
        // @ts-expect-error: prevent old_menu from being destroyed, but is technically invalid
        delete quick_settings.menu;
        quick_settings.setMenu(new_menu);
        Main.layoutManager.connect_object("system-modal-opened", () => new_menu.close(), new_menu);
        // dash-to-panel won't automatically add our new popup in its manager like gnome-shell does
        if (panel && "_setPanelMenu" in panel) {
            // @ts-expect-error: PanelGridMenu is invalid because we override some of its properties
            panel.menuManager.addMenu(new_menu);
        }
        return old_menu;
    }
    move_quick_settings(old_menu, new_menu) {
        for (const item of old_menu.getItems()) {
            const column_span = old_menu.getColumnSpan(item);
            const visible = item.visible;
            old_menu.removeItem(item);
            new_menu.addItem(item, column_span);
            // Adding a widget to another automatically make it visible, so we reset manually
            item.visible = visible;
        }
    }
    add_panel(panel, default_location) {
        const layout = this.get_layout();
        // y-position used for when we don't have a known position
        let max_row = Math.max(...[...layout]
            .filter(([_panel_id, [monitor, _x, _y]]) => monitor === "primary")
            .map(([_panel_id, [_monitor, _x, y]]) => y));
        if (max_row === -Infinity)
            max_row = -1;
        let location = layout.get(panel.panel_id);
        if (!location && default_location) {
            location = default_location;
            layout.set(panel.panel_id, default_location);
            this.save_layout(layout);
        }
        if (location) {
            const grid = this.grids.get(location[0]);
            const available_monitors = this.dash_to_panel_settings?.availableMonitors;
            // add to the grid found in the config if
            // - the grid is the primary one
            // - the grid exists and is in the available monitors
            if (grid &&
                (location[0] === "primary" ||
                    available_monitors?.some(monitor => monitor.id === location[0]))) {
                grid.add_panel(panel, [location[1], location[2]]);
            }
            else {
                // the monitor this panel is on isn't currently plugged, fallback to the main monitor
                // biome-ignore lint/style/noNonNullAssertion: primary is always present
                this.grids.get("primary").add_panel(panel, [0, max_row + 1]);
            }
        }
        else {
            // biome-ignore lint/style/noNonNullAssertion: primary is always present
            this.grids.get("primary").add_panel(panel, [0, max_row + 1]);
            layout.set(panel.panel_id, ["primary", 0, max_row + 1]);
            this.save_layout(layout);
        }
    }
    get_layout() {
        const layout = this.settings.get_value("layout").recursiveUnpack();
        return new Map(Object.entries(layout));
    }
    save_layout(layout) {
        const transformed_layout = Object.fromEntries([...layout.entries()]);
        this.settings.set_value("layout", new GLib.Variant("a{s(sii)}", transformed_layout));
    }
}
