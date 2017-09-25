//
//  Copyright (C) 2014-2015 Abraham Masri
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//


using Gtk;
using Gdk;


namespace Komorebi.OnScreen {

    List<Thumbnail> thumbnailsList;

    public class WallpapersSelector : ScrolledWindow {

        public string path = "/opt/Komorebi/";

        Gtk.Grid grid = new Grid();

        int row = 0;
        int column = 0;

        // Signaled when a thumbnail is clicked
        public signal void wallpaperChanged ();

        public WallpapersSelector () {

            thumbnailsList = new List<Thumbnail>();

            set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
            vexpand = true;
            margin = 20;

            grid.halign = Align.CENTER;
            grid.row_spacing = 5;
            grid.column_spacing = 20;


            getWallpapers();

            // var thumbnail = new Thumbnail.Add();

            // addThumbnail(thumbnail);
            // thumbnailsList.append(thumbnail);

            add(grid);
        }


        public void getWallpapers () {

            clearGrid();

            foreach(var thumbnail in thumbnailsList)
                thumbnailsList.remove(thumbnail);


            File wallpapersFolder = File.new_for_path("/opt/Komorebi");

            try {

                var enumerator = wallpapersFolder.enumerate_children ("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

                FileInfo info;

                while ((info = enumerator.next_file ()) != null)
                    if (info.get_file_type () == FileType.DIRECTORY) {

                        var name = info.get_name();
                        var fullPath = path + name;

                        // Check if we have a valid wallpaper
                        if (File.new_for_path(fullPath + "/wallpaper.jpg").query_exists() &&
                            File.new_for_path(fullPath + "/config").query_exists()) {

                            var thumbnail = new Thumbnail(path, name);

                            // Signals
                            thumbnail.clicked.connect(() => wallpaperChanged());

                            addThumbnail(thumbnail);
                            thumbnailsList.append(thumbnail);
                        } else
                            print(@"[WARNING]: Found an invalid wallpaper with name: $name \n");
                    }

            } catch {
                print("Could not read directory '/opt/Komorebi/'");
            }
        }

        /* Adds a thumbnail to the grid */
        private void addThumbnail (Thumbnail thumbnail) {

            grid.attach (thumbnail, column, row, 1, 1);

            if(column >= 3) {
                row++;
                column = 0;
            } else
                column++;


            thumbnail.show_all();
        }

        /* Clears the grid */
        private void clearGrid() {

            foreach (var widget in grid.get_children ())
                grid.remove(widget);

            column = 0;
            row = 0;
        }

    }
}
