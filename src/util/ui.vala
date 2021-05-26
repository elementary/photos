/*
* Copyright (c) 2011-2013 Yorba Foundation
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

public enum AdjustmentRelation {
    BELOW,
    IN_RANGE,
    ABOVE
}

public enum Direction {
    FORWARD,
    BACKWARD;

    public Spit.Transitions.Direction to_transition_direction () {
        switch (this) {
        case FORWARD:
            return Spit.Transitions.Direction.FORWARD;

        case BACKWARD:
            return Spit.Transitions.Direction.BACKWARD;

        default:
            error ("Unknown Direction %s", this.to_string ());
        }
    }
}

public void spin_event_loop () {
    while (Gtk.events_pending ())
        Gtk.main_iteration ();
}

public AdjustmentRelation get_adjustment_relation (Gtk.Adjustment adjustment, int value) {
    if (value < (int) adjustment.get_value ())
        return AdjustmentRelation.BELOW;
    else if (value > (int) (adjustment.get_value () + adjustment.get_page_size ()))
        return AdjustmentRelation.ABOVE;
    else
        return AdjustmentRelation.IN_RANGE;
}

public Gdk.Rectangle get_adjustment_page (Gtk.Adjustment hadj, Gtk.Adjustment vadj) {
    Gdk.Rectangle rect = Gdk.Rectangle ();
    rect.x = (int) hadj.get_value ();
    rect.y = (int) vadj.get_value ();
    rect.width = (int) hadj.get_page_size ();
    rect.height = (int) vadj.get_page_size ();

    return rect;
}

// Verifies that only the mask bits are set in the modifier field, disregarding mouse and
// key modifers that are not normally of concern (i.e. Num Lock, Caps Lock, etc.).  Mask can be
// one or more bits set, but should only consist of these values:
// * Gdk.ModifierType.SHIFT_MASK
// * Gdk.ModifierType.CONTROL_MASK
// * Gdk.ModifierType.MOD1_MASK (Alt)
// * Gdk.ModifierType.MOD3_MASK
// * Gdk.ModifierType.MOD4_MASK
// * Gdk.ModifierType.MOD5_MASK
// * Gdk.ModifierType.SUPER_MASK
// * Gdk.ModifierType.HYPER_MASK
// * Gdk.ModifierType.META_MASK
//
// (Note: MOD2 seems to be Num Lock in GDK.)
public bool has_only_key_modifier (Gdk.ModifierType field, Gdk.ModifierType mask) {
    return (field
            & (Gdk.ModifierType.SHIFT_MASK
               | Gdk.ModifierType.CONTROL_MASK
               | Gdk.ModifierType.MOD1_MASK
               | Gdk.ModifierType.MOD3_MASK
               | Gdk.ModifierType.MOD4_MASK
               | Gdk.ModifierType.MOD5_MASK
               | Gdk.ModifierType.SUPER_MASK
               | Gdk.ModifierType.HYPER_MASK
               | Gdk.ModifierType.META_MASK)) == mask;
}

public string build_dummy_ui_string (Gtk.ActionGroup[] groups) {
    string ui_string = "<ui>";
    foreach (Gtk.ActionGroup group in groups) {
        foreach (Gtk.Action action in group.list_actions ())
            ui_string += "<accelerator name=\"%s\" action=\"%s\" />".printf (action.name, action.name);
    }
    ui_string += "</ui>";

    return ui_string;
}
