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

public class Camera.Branch : Sidebar.Branch {
    internal static Icon? cameras_icon = null;

    private Gee.HashMap<DiscoveredCamera, Camera.SidebarEntry> camera_map = new Gee.HashMap <
    DiscoveredCamera, Camera.SidebarEntry > ();

    class construct {
        cameras_icon = new GLib.ThemedIcon (Resources.ICON_CAMERAS);
    }

    public Branch () {
        base (new Camera.Grouping (),
              Sidebar.Branch.Options.HIDE_IF_EMPTY | Sidebar.Branch.Options.AUTO_OPEN_ON_NEW_CHILD,
              camera_comparator);

        foreach (DiscoveredCamera camera in CameraTable.get_instance ().get_cameras ())
            add_camera (camera);

        CameraTable.get_instance ().camera_added.connect (on_camera_added);
        CameraTable.get_instance ().camera_removed.connect (on_camera_removed);
    }

    private static int camera_comparator (Sidebar.Entry a, Sidebar.Entry b) {
        if (a == b)
            return 0;

        // Compare based on name.
        int ret = a.get_sidebar_name ().collate (b.get_sidebar_name ());
        if (ret == 0) {
            // Cameras had same name! Fallback to URI comparison.
            Camera.SidebarEntry? cam_a = a as Camera.SidebarEntry;
            Camera.SidebarEntry? cam_b = b as Camera.SidebarEntry;
            assert (cam_a != null && cam_b != null);
            ret = cam_a.get_uri ().collate (cam_b.get_uri ());
        }

        return ret;
    }

    public Camera.SidebarEntry? get_entry_for_camera (DiscoveredCamera camera) {
        return camera_map.get (camera);
    }

    private void on_camera_added (DiscoveredCamera camera) {
        add_camera (camera);
    }

    private void on_camera_removed (DiscoveredCamera camera) {
        remove_camera (camera);
    }

    private void add_camera (DiscoveredCamera camera) {
        assert (!camera_map.has_key (camera));

        Camera.SidebarEntry entry = new Camera.SidebarEntry (camera);
        camera_map.set (camera, entry);

        // want to show before adding page so the grouping is available to graft onto
        graft (get_root (), entry, camera_comparator);
    }

    private void remove_camera (DiscoveredCamera camera) {
        assert (camera_map.has_key (camera));

        Camera.SidebarEntry? entry = camera_map.get (camera);
        assert (entry != null);

        bool removed = camera_map.unset (camera);
        assert (removed);

        prune (entry);
    }
}

public class Camera.Grouping : Sidebar.Grouping {
    public Grouping () {
        base (_ ("Cameras"), Camera.Branch.cameras_icon);
    }
}

public class Camera.SidebarEntry : Sidebar.SimplePageEntry {
    private DiscoveredCamera camera;
    private string uri;

    public SidebarEntry (DiscoveredCamera camera) {
        this.camera = camera;
        this.uri = camera.uri;
    }

    public override string get_sidebar_name () {
        return camera.display_name ?? _ ("Camera");
    }

    public override Icon? get_sidebar_icon () {
        return camera.icon ?? Camera.Branch.cameras_icon;
    }

    protected override Page create_page () {
        return new ImportPage (camera.gcamera, uri, get_sidebar_name (), get_sidebar_icon ());
    }

    public string get_uri () {
        return uri;
    }
}
