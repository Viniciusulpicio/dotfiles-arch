import Gio from "gi://Gio";
import GObject from "gi://GObject";
export function registerClass(options_or_class, cls) {
    let actual_options;
    let actual_cls;
    if (cls === undefined) {
        // @ts-expect-error: checking whether we have a second argument also checks which signature
        // is used, so we know the first argument is the class
        actual_cls = options_or_class;
        actual_options = {};
    }
    else {
        // @ts-expect-error: see above
        actual_options = options_or_class;
        actual_cls = cls;
    }
    const default_name = `LibPanel_${actual_cls.name}`;
    const uuid = current_extension_uuid()?.replace(/[^A-Za-z_-]/g, "-");
    if (uuid === undefined) {
        console.error("Libpanel's registerClass not called from within extension code. Not mangling name");
    }
    else {
        actual_options.GTypeName = `${actual_options.GTypeName || default_name}_${uuid}`;
    }
    return GObject.registerClass(actual_options, actual_cls);
}
/** Python-like split */
export function split(string, sep, maxsplit) {
    const splitted = string.split(sep);
    return maxsplit
        ? splitted.slice(0, maxsplit).concat([splitted.slice(maxsplit).join(sep)])
        : splitted;
}
/** Python-like rsplit */
export function rsplit(string, sep, maxsplit) {
    const splitted = string.split(sep);
    return maxsplit
        ? [splitted.slice(0, -maxsplit).join(sep)].concat(splitted.slice(-maxsplit))
        : splitted;
}
/** Removes an item from an array and returns whether there was something to remove */
export function array_remove(array, item) {
    const index = array.indexOf(item);
    if (index > -1) {
        array.splice(index, 1);
        return true;
    }
    return false;
}
/** Insert one or more items in an array at a specific index */
export function array_insert(array, index, ...items) {
    array.splice(index, 0, ...items);
}
export function get_stack() {
    return new Error().stack
        ?.split("\n")
        .slice(1)
        .map(line => line.trim())
        .filter(Boolean)
        .map(frame => {
        const [func, remaining] = split(frame, "@", 1);
        const [file, line, column] = rsplit(remaining, ":", 2);
        return { func, file, line, column };
    });
}
export function current_extension_uuid() {
    const stack = get_stack();
    if (stack === undefined)
        return undefined;
    for (const frame of stack.reverse()) {
        if (frame.file.includes("/gnome-shell/extensions/")) {
            const [left, right] = frame.file.split("@").slice(-2);
            return `${left.split("/").at(-1)}@${right.split("/")[0]}`;
        }
    }
    return undefined;
}
function get_style(widget) {
    return (widget.style
        ?.split(";")
        .map(x => {
        const [name, value] = split(x, ":", 1).map(x => x.trim());
        return { name, value };
    })
        .filter(x => x.name !== "") || []);
}
export function set_style_value(widget, name, value) {
    const style = get_style(widget).filter(x => x.name !== name);
    if (value !== null)
        style.push({ name, value });
    widget.style = style.map(({ name, value }) => `${name}: ${value}`).join(";");
}
export function get_settings(path) {
    const [parent_path, file] = rsplit(path, "/", 1);
    const id = rsplit(file, ".", 2)[0];
    const source = Gio.SettingsSchemaSource.new_from_directory(parent_path, Gio.SettingsSchemaSource.get_default(), false);
    const schema = source.lookup(id, true);
    if (schema === null)
        throw new Error(`Could not find settings schema: ${path}`);
    return new Gio.Settings({ settings_schema: schema });
}
