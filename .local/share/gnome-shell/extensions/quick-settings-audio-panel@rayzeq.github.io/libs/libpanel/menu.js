import { PopupMenu } from "resource:///org/gnome/shell/ui/popupMenu.js";
import FullscreenBoxpointer from "./boxpointer.js";
import PanelGrid from "./grid.js";
// The spacing between panels in the grid, in pixels.
const GRID_SPACING = 5;
export default class PanelGridMenu extends PopupMenu {
    // @ts-expect-error: replacing some gnome types
    box;
    constructor(source, arrow_alignment, arrow_side, default_panel, settings, monitor) {
        super(source, arrow_alignment, arrow_side);
        const new_boxpointer = new FullscreenBoxpointer(arrow_side);
        // Replace the box
        this.box = new PanelGrid(new_boxpointer, default_panel, settings, monitor);
        this.box.style = `spacing-rows: ${GRID_SPACING}px; spacing-columns: ${GRID_SPACING}px`;
        // Delete some things
        global.focus_manager.remove_group(this.actor);
        this._boxPointer.destroy();
        // Code from PopupMenu's constructor
        this._boxPointer = new_boxpointer;
        this.actor = this._boxPointer;
        this.actor._delegate = this;
        this.actor.style_class = "popup-menu-boxpointer";
        this._boxPointer.bin.set_child(this.box);
        this.actor.add_style_class_name("popup-menu");
        global.focus_manager.add_group(this.actor);
        this.actor.reactive = true;
    }
    get transparent() {
        return this._boxPointer.transparent && this.box.transparent;
    }
    set transparent(value) {
        this._boxPointer.transparent = value;
    }
    get panels() {
        return this.box.get_panels();
    }
    close(params) {
        for (const panel of this.panels) {
            panel.close?.();
        }
        super.close(params);
    }
    add_panel(panel, position) {
        this.box.add_child(panel);
        if (position) {
            this.box.set_column(panel, position[0]);
            this.box.set_row(panel, position[1]);
        }
    }
    remove_all_panels() {
        const panels = this.box.get_panels();
        let gnome_panel;
        for (const [i, panel] of panels.entries()) {
            if (panel.panel_id.startsWith("gnome-shell/main")) {
                panels.splice(i, 1);
                gnome_panel = [panel, [this.box.get_column(panel), this.box.get_row(panel)]];
                // we only support one gnome panel per monitor, stop there
                // (and this means we don't have to care about the fact that we're editing the
                // list while iterating through it)
                break;
            }
        }
        this.box.remove_all_children();
        if (gnome_panel) {
            this.add_panel(...gnome_panel);
        }
        return panels;
    }
}
