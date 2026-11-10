import Clutter from "gi://Clutter";
import Cogl from "gi://Cogl";
import GObject from "gi://GObject";
import St from "gi://St";
import * as DND from "resource:///org/gnome/shell/ui/dnd.js";
import * as Main from "resource:///org/gnome/shell/ui/main.js";
import { LibPanel } from "./main.js";
import { current_extension_uuid, registerClass, set_style_value } from "./utils.js";
// biome-ignore lint/style/noNonNullAssertion: should always be defined
const QuickSettingsLayoutConstructor = Main.panel.statusArea.quickSettings.menu._grid
    .layout_manager.constructor;
// Base panel, reproducing gnome's QuickSettingsMenu
const BasePanel = registerClass(class BasePanel extends St.Widget {
    panel_id;
    is_destroyed;
    // Do not rename. Those are the same names that the ones used by QuickSettingsMenu
    _overlay;
    _grid;
    _dimEffect;
    _activeMenu;
    constructor(id, n_columns = 2, properties) {
        super({
            // Enable this so the menu block click events from propagating through
            reactive: true,
            ...properties,
        });
        this.panel_id = `${current_extension_uuid()}/${id}`;
        // Overlay layer that will contain sub-menus
        this._overlay = new Clutter.Actor({ layout_manager: new Clutter.BinLayout() });
        // Placeholder to make empty space when opening a sub-menu
        const placeholder = new Clutter.Actor({
            // The placeholder have the same height as the overlay, which means
            // it have the same height as the opened sub-menu
            constraints: new Clutter.BindConstraint({
                coordinate: Clutter.BindCoordinate.HEIGHT,
                source: this._overlay,
            }),
        });
        this._grid = new St.Widget({
            style_class: "popup-menu-content quick-settings quick-settings-grid",
            layout_manager: new QuickSettingsLayoutConstructor(placeholder, { nColumns: n_columns }),
        });
        // Force the grid to take up all the available width
        this._grid.add_constraint(new Clutter.BindConstraint({
            coordinate: Clutter.BindCoordinate.WIDTH,
            source: this,
        }));
        this.add_child(this._grid);
        this._grid.add_child(placeholder);
        const x_constraint = new Clutter.BindConstraint({
            coordinate: Clutter.BindCoordinate.X,
            source: this._grid,
        });
        const width_constraint = new Clutter.BindConstraint({
            coordinate: Clutter.BindCoordinate.WIDTH,
            source: this._grid,
        });
        this._overlay.add_constraint(x_constraint);
        this._overlay.add_constraint(width_constraint);
        this._grid.connect("style-changed", _source => {
            const grid_theme = this._grid.get_theme_node();
            x_constraint.offset = grid_theme.get_padding(St.Side.LEFT);
            width_constraint.offset =
                -grid_theme.get_padding(St.Side.LEFT) - grid_theme.get_padding(St.Side.RIGHT);
        });
        this.add_child(this._overlay);
        this._dimEffect = new Clutter.BrightnessContrastEffect({ enabled: false });
        this._grid.add_effect_with_name("dim", this._dimEffect);
        this.is_destroyed = true;
        this.connect("destroy", () => {
            this.is_destroyed = true;
        });
    }
    getItems() {
        // Every child except the placeholder
        return this._grid
            .get_children()
            .filter(item => item !== this._grid.layout_manager._overlay);
    }
    getFirstItem() {
        return this.getItems()[0];
    }
    addItem(item, column_span = 1) {
        this._grid.add_child(item);
        this._completeAddItem(item, column_span);
    }
    insertItemBefore(item, sibling, column_span = 1) {
        this._grid.insert_child_below(item, sibling);
        this._completeAddItem(item, column_span);
    }
    _completeAddItem(item, column_span) {
        this.setColumnSpan(item, column_span);
        if ("menu" in item && item.menu) {
            this._overlay.add_child(item.menu.actor);
            item.menu.connect_object("open-state-changed", (_, is_open) => {
                this._setDimmed(is_open);
                this._activeMenu = is_open ? item.menu : undefined;
                // The sub-popup for the power menu is too high.
                // I don't know if it's the real source of the issue, but I suspect that the constraint that fixes its y position
                // isn't accounting for the padding of the grid, so we add it to the offset manually
                // Later: I added the name check because it breaks on the audio panel
                // so I'm almost certain that this is not a proper fix
                // Later later: it seems the padding really does have something to do with it
                // it's like the constraint doesn't take it into account but just for the
                // powermenu. At this point I'm starting to think it's a clutter bug
                if (is_open &&
                    this.getItems().indexOf(item) === 0 &&
                    this.panel_id.startsWith("gnome-shell/main")) {
                    const constraint = item.menu.actor.get_constraints()[0];
                    constraint.offset =
                        // the offset is normally bound to the height of the source
                        constraint.source.height + this._grid.get_theme_node().get_padding(St.Side.TOP);
                    // note: we don't reset this property when the item is removed from this panel because
                    // we hope that it will reset itself (because it's bound to the height of the source),
                    // which in the case in my tests, but maybe some issue will arise because of this
                }
                return false;
            }, this);
        }
        if ("_menuButton" in item && item._menuButton) {
            // @ts-expect-error: hack
            item._menuButton.__libpanel_y_expand_backup = item._menuButton.y_expand;
            item._menuButton.y_expand = false;
        }
    }
    removeItem(item) {
        if (!this._grid.get_children().includes(item))
            console.error(`[LibPanel] ${current_extension_uuid()} tried to remove an item not in the panel`);
        item.get_parent()?.remove_child(item);
        if ("menu" in item && item.menu) {
            item.menu.disconnect_object(this);
            item.menu.actor?.get_parent()?.remove_child(item.menu.actor);
        }
        if ("_menuButton" in item && item._menuButton) {
            // @ts-expect-error: hack
            item._menuButton.y_expand = item._menuButton.__libpanel_y_expand_backup;
            // @ts-expect-error: hack
            delete item._menuButton.__libpanel_y_expand_backup;
        }
    }
    getColumnSpan(item) {
        if (!this._grid.get_children().includes(item))
            console.error(`[LibPanel] ${current_extension_uuid()} tried to get the column span of an item not in the panel`);
        const value = new GObject.Value();
        this._grid.layout_manager.child_get_property(this._grid, item, "column-span", value);
        const column_span = value.get_int();
        value.unset();
        return column_span;
    }
    setColumnSpan(item, column_span) {
        if (!this._grid.get_children().includes(item))
            console.error(`[LibPanel] ${current_extension_uuid()} tried to set the column span of an item not in the panel`);
        this._grid.layout_manager.child_set_property(this._grid, item, "column-span", column_span);
    }
    close() {
        this._activeMenu?.close({ animate: false });
    }
    _setDimmed(dim) {
        // copied from https://gitlab.gnome.org/GNOME/gnome-shell/-/blob/main/js/ui/quickSettings.js
        const DIM_BRIGHTNESS = -0.4;
        const POPUP_ANIMATION_TIME = 400;
        const val = 127 * (1 + (dim ? 1 : 0) * DIM_BRIGHTNESS);
        const color = new Cogl.Color({
            red: val,
            green: val,
            blue: val,
            alpha: 255,
        });
        this._grid.ease_property("@effects.dim.brightness", color, {
            mode: Clutter.AnimationMode.LINEAR,
            duration: POPUP_ANIMATION_TIME,
            onStopped: () => (this._dimEffect.enabled = dim),
        });
        this._dimEffect.enabled = true;
    }
    set_padding(padding) {
        set_style_value(this._grid, "padding", padding !== null ? `${padding}px` : null);
    }
    set_row_spacing(row_spacing) {
        set_style_value(this._grid, "spacing-rows", row_spacing !== null ? `${row_spacing}px` : null);
    }
    set_column_spacing(column_spacing) {
        set_style_value(this._grid, "spacing-columns", column_spacing !== null ? `${column_spacing}px` : null);
    }
    shadow_class_name() {
        return `${this.style_class} ${this._grid.style_class}`;
    }
});
const DragShadow = registerClass(class DragShadow extends St.Widget {
    drag_position;
    grid_position;
    constructor(source) {
        super({ style_class: source.shadow_class_name(), opacity: 127 });
        this.add_constraint(new Clutter.BindConstraint({
            coordinate: Clutter.BindCoordinate.WIDTH,
            source,
        }));
        this.add_constraint(new Clutter.BindConstraint({
            coordinate: Clutter.BindCoordinate.HEIGHT,
            source,
        }));
    }
});
const DraggablePanel = registerClass(class DraggablePanel extends BasePanel {
    draggable;
    drag_monitor;
    drag_shadow;
    constructor(id, n_columns = 2, properties) {
        super(id, n_columns, properties);
        this.draggable = DND.makeDraggable(this, {});
        this.drag_shadow = new DragShadow(this);
        this.drag_monitor = {
            dragMotion: event => {
                const shadow_monitor_index = Main.layoutManager.findIndexForActor(this.drag_shadow);
                const monitor_index = Main.layoutManager.findIndexForActor(this);
                // get the parent from the drag shadow because the DND system has moved us out of the grid
                // biome-ignore lint/style/noNonNullAssertion: the shadow is always supposed to have a parent
                let parent = this.drag_shadow.get_parent();
                let grid;
                if (shadow_monitor_index !== monitor_index) {
                    grid = LibPanel._get_grid(monitor_index);
                    if (grid) {
                        parent = grid.box;
                        if (!grid.isOpen) {
                            // Grabs are handled in a stack, so we pop the grab from the DND system,
                            // then push the grab for the newly opened menu (though grid.open),
                            // then push back the DND grab.
                            // This way the DND grab stays on top of the stack.
                            const grab_actor = Main.modalActorFocusStack[Main.modalActorFocusStack.length - 1].actor;
                            Main.popModal(this.draggable._grab);
                            grid.open({ animate: false });
                            this.draggable._grab = Main.pushModal(grab_actor);
                            // Prevent this (the panel being dragged visually) from being behind the newly opened grid
                            Main.layoutManager.uiGroup.set_child_above_sibling(this, null);
                        }
                    }
                }
                const [_, x, y] = parent.transform_stage_point(event.x, event.y);
                this.drag_shadow.drag_position = [x, y];
                if (shadow_monitor_index !== monitor_index && grid) {
                    this.drag_shadow.get_parent()?.remove_child(this.drag_shadow);
                    grid.box.add_child(this.drag_shadow);
                }
                return DND.DragMotionResult.MOVE_DROP;
            },
            dragDrop: _event => {
                const grid = this.drag_shadow.get_parent();
                grid.remove_child(this.drag_shadow);
                DND.removeDragMonitor(this.drag_monitor);
                this.draggable._dragComplete();
                this.get_parent()?.remove_child(this);
                // the DND system doesn't properly unset the fixed size
                this.set_size(-1, -1);
                grid.add_child(this);
                const new_position = this.drag_shadow.grid_position || [0, 0];
                // shift all panels after the one we add
                for (const panel of grid.get_panels()) {
                    const row = grid.get_row(panel);
                    if (grid.get_column(panel) === new_position[0] && row >= new_position[1]) {
                        grid.set_row(panel, row + 1);
                    }
                }
                grid.set_column(this, new_position[0]);
                grid.set_row(this, new_position[1]);
                LibPanel._move_panel(this, grid.monitor, ...new_position);
                return DND.DragDropResult.SUCCESS;
            },
        };
        this.draggable.connect("drag-begin", () => {
            DND.addDragMonitor(this.drag_monitor);
            const grid = this.get_parent();
            const [_, x, y] = grid.transform_stage_point(
            // biome-ignore lint/style/noNonNullAssertion: always set after drag-begin is emitted
            this.draggable._dragStartX, 
            // biome-ignore lint/style/noNonNullAssertion: always set after drag-begin is emitted
            this.draggable._dragStartY);
            this.drag_shadow.drag_position = [x, y];
            grid.add_child(this.drag_shadow);
            const column = grid.get_column(this);
            const row = grid.get_row(this);
            // shift all panels to fill the hole we left
            for (const panel of grid.get_panels()) {
                const panel_row = grid.get_row(panel);
                if (grid.get_column(panel) === column && panel_row > row) {
                    grid.set_row(panel, panel_row - 1);
                }
            }
        });
        this.connect("destroy", () => {
            DND.removeDragMonitor(this.drag_monitor);
            this.drag_shadow.destroy();
        });
    }
    set_dnd_enabled(enabled) {
        this.draggable._dndGesture.manual_mode = !enabled;
    }
});
const AutohidingPanel = registerClass(class AutohidingPanel extends DraggablePanel {
    constructor(id, n_columns = 2, properties) {
        super(id, n_columns, properties);
        this._grid.connect("child-added", (_, child) => {
            const handler_id = child.connect("notify::visible", () => this._update_visibility());
            // @ts-expect-error: hack
            child.__libpanel_handler_id = handler_id;
            this._update_visibility();
        });
        this._grid.connect("child-removed", (_, child) => {
            // The check is needed because the placeholder doesn't have the signal
            // @ts-expect-error: hack
            if (child.__libpanel_handler_id) {
                // @ts-expect-error: hack
                child.disconnect(child.__libpanel_handler_id);
                // @ts-expect-error: hack
                delete child.__libpanel_handler_id;
            }
            this._update_visibility();
        });
    }
    _update_visibility() {
        for (const child of this.getItems()) {
            if (child.visible) {
                this.show();
                return;
            }
        }
        this.hide();
    }
});
export default AutohidingPanel;
