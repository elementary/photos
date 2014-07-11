/* Copyright 2011-2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class Metadata : Gtk.ScrolledWindow {
    public BasicProperties basic_properties = new BasicProperties ();
	//private MetadataTable table = new MetadataTable ();
	
	public Metadata ()
	{
		        set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);

        get_style_context().add_class(Gtk.STYLE_CLASS_SIDEBAR);
var rating_widget = new Granite.Widgets.PhotosRating (true, Gtk.IconSize.MENU,true);
		this.add(rating_widget);
	}
}

public class MetadataTable : Gtk.Grid {
	uint line_count = 0;
	public MetadataTable ()
	{
						var entry = new Gtk.Entry ();
		entry.set_text ("test");
	//	add_line("test",entry);
		//var rating_widget = new Gtk.EventBox();
		var rating_widget = new Granite.Widgets.PhotosRating (true, Gtk.IconSize.MENU,true);
		attach(rating_widget,0,(int) line_count, 1, 1);
		line_count++;
	}

	public void add_line(string label_text, Gtk.Entry entry) {
        Gtk.Label label = new Gtk.Label(label_text);


        label.set_justify(Gtk.Justification.RIGHT);
        label.set_markup(GLib.Markup.printf_escaped("<span font_weight=\"bold\">%s</span>", label_text));

        attach(label, 0, (int) line_count, 1, 1);
		attach(entry, 1, (int) line_count, 1, 1);
        line_count++;
    }
}