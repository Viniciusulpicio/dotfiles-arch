import GObject from "gi://GObject";
import { registerClass } from "./utils.js";
export function Semitransparent(superclass) {
    if (!Semitransparent.cache)
        Semitransparent.cache = new Map();
    const cached = Semitransparent.cache.get(superclass.name);
    if (cached)
        return cached;
    const klass = registerClass({
        GTypeName: `LibPanel_Semitransparent_${superclass.name}`,
        Properties: {
            transparent: GObject.ParamSpec.boolean("transparent", "Transparent", "Whether this widget is transparent to pointer events", GObject.ParamFlags.READWRITE, true),
        },
    }, class extends superclass {
        _transparent;
        get transparent() {
            if (this._transparent === undefined)
                this._transparent = true;
            return this._transparent;
        }
        set transparent(value) {
            if (this._transparent === value)
                return;
            this._transparent = value;
            this.notify("transparent");
        }
        vfunc_pick(context) {
            if (!this.transparent)
                super.vfunc_pick(context);
            for (const child of this.get_children())
                child.pick(context);
        }
    });
    Semitransparent.cache.set(superclass.name, klass);
    return klass;
}
