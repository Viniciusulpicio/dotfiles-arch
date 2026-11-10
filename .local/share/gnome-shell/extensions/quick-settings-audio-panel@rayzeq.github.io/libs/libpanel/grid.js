import Clutter from "gi://Clutter";
import GLib from "gi://GLib";
import GObject from "gi://GObject";
import St from "gi://St";
import { Semitransparent } from "./mixins.js";
import { registerClass } from "./utils.js";
const GRID_SPACING = 5;
const PanelGridLayoutMeta = registerClass({
    Properties: {
        column: GObject.ParamSpec.int("column", null, null, GObject.ParamFlags.READWRITE, GLib.MININT32, GLib.MAXINT32, 0),
        row: GObject.ParamSpec.int("row", null, null, GObject.ParamFlags.READWRITE, GLib.MININT32, GLib.MAXINT32, 0),
    },
}, class PanelGridLayoutMeta extends Clutter.LayoutMeta {
});
const PanelGridLayout = registerClass({
    Properties: {
        "row-spacing": GObject.ParamSpec.int("row-spacing", null, null, GObject.ParamFlags.READWRITE, 0, GLib.MAXINT32, GRID_SPACING),
        "column-spacing": GObject.ParamSpec.int("column-spacing", null, null, GObject.ParamFlags.READWRITE, 0, GLib.MAXINT32, GRID_SPACING),
    },
}, class PanelGridLayout extends Clutter.LayoutManager {
    _container;
    _get_child_properties(container, child) {
        // We assume that the meta layout manager is the right type
        return this.get_child_meta(container, child);
    }
    _container_style_changed() {
        // We assume that there is a container (should be always true if this function is always called from the signal)
        // and that it's a subclass of St.Widget and not Clutter.Actor
        const node = this._container.get_theme_node();
        let changed = false;
        let found, length;
        [found, length] = node.lookup_length("spacing-rows", false);
        changed ||= found;
        if (found)
            this.row_spacing = length;
        [found, length] = node.lookup_length("spacing-columns", false);
        changed ||= found;
        if (found)
            this.column_spacing = length;
        if (changed)
            this.layout_changed();
    }
    vfunc_get_child_meta_type() {
        return PanelGridLayoutMeta.$gtype;
    }
    vfunc_set_container(container) {
        this._container?.disconnect_object(this);
        this._container = container;
        this._container?.connect_object("style-changed", () => this._container_style_changed(), this);
    }
    vfunc_get_preferred_width(_container, _for_height) {
        return [-1, -1];
    }
    vfunc_get_preferred_height(_container, _for_width) {
        return [-1, -1];
    }
    vfunc_allocate(container_, box) {
        // We assume that the container is always a PanelGrid
        const container = container_;
        const arrow_side = container.boxpointer._arrowSide;
        const is_vertical = arrow_side === St.Side.TOP || arrow_side === St.Side.BOTTOM;
        const groups = new Map();
        groups.set(0, { pref: 1, min: 1, widgets: [] });
        let drag_shadow;
        const children = container.get_children();
        for (const child of children) {
            if (!child.visible)
                continue;
            if ("drag_position" in child) {
                // breaks if there are multiple drag shadow,
                // it should never happen so it's okay
                drag_shadow = child;
                continue;
            }
            const { column: index } = this._get_child_properties(container, child);
            if (!groups.has(index))
                groups.set(index, { pref: 1, min: 1, widgets: [] });
            const [min_width, min_height, pref_width, pref_height] = child.get_preferred_size();
            // biome-ignore lint/style/noNonNullAssertion: this is checked above
            const group = groups.get(index);
            group.min = Math.max(group.min, is_vertical ? min_width : min_height);
            group.pref = Math.max(group.pref, is_vertical ? pref_width : pref_height);
            group.widgets.push(child);
        }
        // Handle secondary side flipping
        const secondary_side = container.boxpointer.secondary_side;
        let flipped_factor = 1;
        if (secondary_side === St.Side.RIGHT || secondary_side === St.Side.BOTTOM) {
            const copy = new Map(groups);
            groups.clear();
            copy.forEach((props, group_index) => {
                groups.set(group_index * -1, props);
            });
            flipped_factor = -1;
        }
        // Fill missing (empty) groups
        const min_group = Math.min(...groups.keys());
        const max_group = Math.max(...groups.keys());
        for (let group_index = min_group; group_index <= max_group; group_index++) {
            if (!groups.has(group_index))
                groups.set(group_index, { pref: 1, min: 1, widgets: [] });
        }
        // Calculate middle group position
        // biome-ignore lint/style/noNonNullAssertion: 0 is always in the groups
        const middle_group = groups.get(0);
        // biome-ignore lint/style/noNonNullAssertion: if this method was called, we have a parent (probably, I don't remember why I put this here)
        let parent = container.get_parent();
        let success, center_x, center_y;
        do {
            // `container.boxpointer.center` may be on the x or y axis. We compute both and choose the right one after
            [success, center_x, center_y] = parent.transform_stage_point(container.boxpointer.center, container.boxpointer.center);
            // biome-ignore lint/style/noNonNullAssertion: no idea why this is guaranteed to not be null
            parent = parent.get_parent();
        } while (!success);
        const [min_width, min_height, pref_width, pref_height] = container.default_panel.get_preferred_size();
        const default_min_size = is_vertical ? min_width : min_height;
        const max_empty_size = is_vertical ? pref_width : pref_height;
        // force the middle group to have a reasonable size even if empty
        if (middle_group.widgets.length === 0) {
            middle_group.min = default_min_size;
            middle_group.pref = max_empty_size;
        }
        const main_min = is_vertical ? box.x1 : box.y1;
        const main_max = is_vertical ? box.x2 : box.y2;
        const middle_group_half = middle_group.pref / 2;
        const center_main = Math.min(Math.max(is_vertical ? center_x : center_y, main_min + middle_group_half), main_max - middle_group_half);
        // Fit left/top groups
        const left_max = center_main - middle_group_half;
        const left_space = left_max - main_min;
        let remaining_space_left = this._fit_groups(Array.from(groups)
            .filter(([index, _]) => index < 0)
            .map(([_, group]) => group), left_space, max_empty_size);
        if (remaining_space_left > 0) {
            let new_min_group = min_group - 1;
            remaining_space_left -= this.column_spacing;
            while (remaining_space_left > 0) {
                const size = Math.min(max_empty_size, remaining_space_left);
                groups.set(new_min_group, { pref: size, min: 1, widgets: [] });
                remaining_space_left -= size + this.column_spacing;
                new_min_group -= 1;
            }
        }
        // Fit right/bottom groups
        const right_min = center_main + middle_group_half;
        const right_space = main_max - right_min;
        let remaining_space_right = this._fit_groups(Array.from(groups)
            .filter(([index, _]) => index > 0)
            .map(([_, group]) => group), right_space, max_empty_size);
        if (remaining_space_right > 0) {
            let new_max_group = max_group + 1;
            remaining_space_right -= this.column_spacing;
            while (remaining_space_right > 0) {
                const size = Math.min(max_empty_size, remaining_space_right);
                groups.set(new_max_group, { pref: size, min: 1, widgets: [] });
                remaining_space_right -= size + this.column_spacing;
                new_max_group += 1;
            }
        }
        const left_groups = Array.from(groups)
            .filter(([index, _]) => index < 0)
            .sort((a, b) => b[0] - a[0]);
        const right_groups = Array.from(groups)
            .filter(([index, _]) => index > 0)
            .sort((a, b) => a[0] - b[0]);
        if (drag_shadow?.drag_position) {
            const drag_position = drag_shadow.drag_position;
            drag_position[0] = Math.max(box.x1, Math.min(drag_position[0], box.x2));
            drag_position[1] = Math.max(box.y1, Math.min(drag_position[1], box.y2));
            const main_pos = is_vertical ? drag_shadow.drag_position[0] : drag_shadow.drag_position[1];
            let group;
            if (center_main - middle_group_half - this.column_spacing / 2 < main_pos &&
                main_pos < center_main + middle_group_half + this.column_spacing / 2) {
                group = middle_group;
                drag_shadow.grid_position = [0, NaN];
            }
            else if (main_pos < center_main - middle_group_half - this.column_spacing / 2) {
                // default to the left-most group
                const default_group = left_groups[left_groups.length - 1];
                group = default_group[1];
                drag_shadow.grid_position = [default_group[0] * flipped_factor, NaN];
                let pos = left_max - this.column_spacing / 2;
                for (const [i, g] of left_groups) {
                    if (pos - g.pref - this.column_spacing < main_pos && main_pos < pos) {
                        group = g;
                        drag_shadow.grid_position = [i * flipped_factor, NaN];
                        break;
                    }
                    pos -= group.pref + this.column_spacing;
                }
            }
            else {
                // default to the right-most group
                group = right_groups[0][1];
                drag_shadow.grid_position = [right_groups[0][0] * flipped_factor, NaN];
                let pos = right_min + this.column_spacing / 2;
                for (const [i, g] of right_groups) {
                    if (pos < main_pos && main_pos < pos + group.pref + this.column_spacing) {
                        group = g;
                        drag_shadow.grid_position = [i * flipped_factor, NaN];
                        break;
                    }
                    pos += group.pref + this.column_spacing;
                }
            }
            group.drag_shadow = drag_shadow;
        }
        // Allocate groups
        this._allocate_group(middle_group, center_main - middle_group_half, box, container, arrow_side);
        let main_pos = left_max - this.column_spacing;
        for (const [_, group] of left_groups) {
            main_pos -= group.pref;
            this._allocate_group(group, main_pos, box, container, arrow_side);
            main_pos -= this.column_spacing;
        }
        main_pos = right_min + this.column_spacing;
        for (const [_, group] of right_groups) {
            this._allocate_group(group, main_pos, box, container, arrow_side);
            main_pos += group.pref + this.column_spacing;
        }
    }
    /**
     * Resize a list of rows or columns (groups) to fit in `space`.
     * The final size will be written in
     *
     * @param spacing - The space between each group.
     * @param max_empty_size - The maximum size of empty groups.
     * @returns The remaining space and size of empty groups, if any.
     */
    _fit_groups(groups, space, max_empty_size) {
        const min_space = groups.reduce((sum, g) => sum + g.min + this.column_spacing, 0);
        const pref_space = groups.reduce((sum, g) => sum + g.pref + this.column_spacing, 0);
        if (min_space > space) {
            const group_size = Math.max((space - this.column_spacing * groups.length) / groups.length, 1);
            groups.forEach(g => {
                g.pref = group_size;
            });
        }
        else if (pref_space > space) {
            let to_remove = pref_space - space;
            let shrinkable_count = groups.length;
            while (to_remove > 0 && shrinkable_count > 0) {
                const per_group = to_remove / shrinkable_count;
                for (const group of groups) {
                    if (group.pref <= group.min)
                        continue;
                    const reduction = Math.min(per_group, group.pref - group.min);
                    group.pref -= reduction;
                    to_remove -= reduction;
                    if (group.pref === group.min)
                        shrinkable_count--;
                }
            }
        }
        else if (pref_space < space) {
            let remaining_space = space - pref_space;
            const empty_groups = groups.filter(g => g.widgets.length === 0);
            const empty_size = Math.min(remaining_space / empty_groups.length, max_empty_size);
            remaining_space -= empty_size * empty_groups.length;
            empty_groups.forEach(g => {
                g.pref = empty_size;
            });
            return remaining_space;
        }
        return 0;
    }
    _allocate_group(group, main_pos, box, container, arrow_side) {
        const is_vertical = arrow_side === St.Side.TOP || arrow_side === St.Side.BOTTOM;
        const direction = arrow_side === St.Side.TOP || arrow_side === St.Side.LEFT ? 1 : -1;
        let cross_pos;
        switch (arrow_side) {
            case St.Side.TOP:
                cross_pos = box.y1;
                break;
            case St.Side.BOTTOM:
                cross_pos = box.y2;
                break;
            case St.Side.LEFT:
                cross_pos = box.x1;
                break;
            case St.Side.RIGHT:
                cross_pos = box.x2;
                break;
        }
        group.widgets.sort((a, b) => this._get_child_properties(container, a).row -
            this._get_child_properties(container, b).row);
        let shadow_rendered = false;
        for (const child of group.widgets) {
            const [_min_width, _min_height, pref_width, pref_height] = child.get_preferred_size();
            const child_cross_size = is_vertical ? pref_height : pref_width;
            let child_box = this.make_box(arrow_side, main_pos, cross_pos, group.pref, child_cross_size);
            if (group.drag_shadow?.drag_position) {
                const shadow_cross_pos = is_vertical
                    ? group.drag_shadow.drag_position[1]
                    : group.drag_shadow.drag_position[0];
                if ((direction === 1 &&
                    cross_pos - this.row_spacing / 2 < shadow_cross_pos &&
                    shadow_cross_pos < cross_pos + child_cross_size + this.row_spacing / 2) ||
                    (direction === -1 &&
                        cross_pos - child_cross_size - this.row_spacing / 2 < shadow_cross_pos &&
                        shadow_cross_pos < cross_pos + this.row_spacing / 2)) {
                    const [_min_width, _min_height, pref_width, pref_height] = group.drag_shadow.get_preferred_size();
                    const cross_size = is_vertical ? pref_height : pref_width;
                    if ((direction === 1 && shadow_cross_pos < cross_pos + child_cross_size / 2) ||
                        (direction === -1 && shadow_cross_pos > cross_pos - child_cross_size / 2)) {
                        group.drag_shadow.allocate(this.make_box(arrow_side, main_pos, cross_pos, group.pref, cross_size));
                        const new_pos = cross_pos + (cross_size + this.row_spacing) * direction;
                        child_box = this.make_box(arrow_side, main_pos, new_pos, group.pref, child_cross_size);
                        cross_pos = new_pos;
                        // biome-ignore lint/style/noNonNullAssertion: this is set by the caller
                        group.drag_shadow.grid_position[1] = this._get_child_properties(container, child).row;
                    }
                    else {
                        group.drag_shadow.allocate(this.make_box(arrow_side, main_pos, cross_pos + (child_cross_size + this.row_spacing) * direction, group.pref, cross_size));
                        cross_pos += (cross_size + this.row_spacing) * direction;
                        // biome-ignore lint/style/noNonNullAssertion: this is set by the caller
                        group.drag_shadow.grid_position[1] =
                            this._get_child_properties(container, child).row + 1;
                    }
                    shadow_rendered = true;
                }
            }
            child.allocate(child_box);
            cross_pos += (child_cross_size + this.row_spacing) * direction;
        }
        if (group.drag_shadow?.drag_position && !shadow_rendered) {
            const [_min_width, _min_height, pref_width, pref_height] = group.drag_shadow.get_preferred_size();
            const cross_size = is_vertical ? pref_height : pref_width;
            group.drag_shadow.allocate(this.make_box(arrow_side, main_pos, cross_pos, group.pref, cross_size));
            const last = group.widgets[group.widgets.length - 1];
            // biome-ignore lint/style/noNonNullAssertion: this is set by the caller
            group.drag_shadow.grid_position[1] = last
                ? this._get_child_properties(container, last).row + 1
                : 0;
        }
    }
    make_box(arrow_side, main_position, cross_position, main_size, cross_size) {
        const box = new Clutter.ActorBox();
        switch (arrow_side) {
            case St.Side.TOP:
                box.set_size(main_size, cross_size);
                box.set_origin(main_position, cross_position);
                break;
            case St.Side.BOTTOM:
                box.set_size(main_size, cross_size);
                box.set_origin(main_position, cross_position - cross_size);
                break;
            case St.Side.LEFT:
                box.set_size(cross_size, main_size);
                box.set_origin(cross_position, main_position);
                break;
            case St.Side.RIGHT:
                box.set_size(cross_size, main_size);
                box.set_origin(cross_position - cross_size, main_position);
                break;
        }
        return box;
    }
});
const PanelGrid = registerClass(class PanelGrid extends Semitransparent(St.Widget) {
    boxpointer;
    default_panel;
    monitor;
    settings;
    constructor(boxpointer, default_panel, settings, monitor) {
        super({ layout_manager: new PanelGridLayout(), x_expand: true, y_expand: true });
        this.boxpointer = boxpointer;
        this.default_panel = default_panel;
        this.settings = settings;
        this.monitor = monitor;
        // https://gjs-docs.gnome.org/gio20~2.0/gio.settings#signal-changed
        // "Note that @settings only emits this signal if you have read key at
        // least once while a signal handler was already connected for key."
        // Those key will be read when the first panel is added
        this.settings.connect_object("changed::dnd-enabled", () => {
            const enabled = this.settings.get_boolean("dnd-enabled");
            for (const child of this.get_panels()) {
                child.set_dnd_enabled?.(enabled);
            }
        }, this);
        this.settings.connect_object("changed::padding-enabled", () => {
            const enabled = this.settings.get_boolean("padding-enabled");
            const value = this.settings.get_int("padding");
            for (const child of this.get_panels()) {
                child.set_padding?.(enabled ? value : null);
            }
        }, this);
        this.settings.connect_object("changed::padding", () => {
            if (!this.settings.get_boolean("padding-enabled"))
                return;
            const value = this.settings.get_int("padding");
            for (const child of this.get_panels()) {
                child.set_padding?.(value);
            }
        }, this);
        this.settings.connect_object("changed::row-spacing-enabled", () => {
            const enabled = this.settings.get_boolean("row-spacing-enabled");
            const value = this.settings.get_int("row-spacing");
            for (const child of this.get_panels()) {
                child.set_row_spacing?.(enabled ? value : null);
            }
        }, this);
        this.settings.connect_object("changed::row-spacing", () => {
            if (!this.settings.get_boolean("row-spacing-enabled"))
                return;
            const value = this.settings.get_int("row-spacing");
            for (const child of this.get_panels()) {
                child.set_row_spacing?.(value);
            }
        }, this);
        this.settings.connect_object("changed::column-spacing-enabled", () => {
            const enabled = this.settings.get_boolean("column-spacing-enabled");
            const value = this.settings.get_int("column-spacing");
            for (const child of this.get_panels()) {
                child.set_column_spacing?.(enabled ? value : null);
            }
        }, this);
        this.settings.connect_object("changed::column-spacing", () => {
            if (!this.settings.get_boolean("column-spacing-enabled"))
                return;
            const value = this.settings.get_int("column-spacing");
            for (const child of this.get_panels()) {
                child.set_column_spacing?.(value);
            }
        }, this);
        this.connect("child-added", (_, child) => {
            child.set_dnd_enabled?.(settings.get_boolean("dnd-enabled"));
            child.set_padding?.(settings.get_boolean("padding-enabled") ? settings.get_int("padding") : null);
            child.set_row_spacing?.(settings.get_boolean("row-spacing-enabled") ? settings.get_int("row-spacing") : null);
            child.set_column_spacing?.(settings.get_boolean("column-spacing-enabled")
                ? settings.get_int("column-spacing")
                : null);
        });
    }
    get_column(actor) {
        const value = new GObject.Value();
        this.layout_manager.child_get_property(this, actor, "column", value);
        const column = value.get_int();
        value.unset();
        return column;
    }
    get_row(actor) {
        const value = new GObject.Value();
        this.layout_manager.child_get_property(this, actor, "row", value);
        const column = value.get_int();
        value.unset();
        return column;
    }
    set_column(actor, column) {
        this.layout_manager.child_set_property(this, actor, "column", column);
    }
    set_row(actor, row) {
        this.layout_manager.child_set_property(this, actor, "row", row);
    }
    get_panels() {
        // just assume that we have only valid panels
        return this.get_children();
    }
});
export default PanelGrid;
