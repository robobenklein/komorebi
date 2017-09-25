//
//  Copyright (C) 2016-2017 Abraham Masri
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
using Gst;

using Komorebi.Utilities;

namespace Komorebi.OnScreen {

    // Global - Name of active wallpaper
    string wallpaperName;

    // Global - Show info box
    bool showInfoBox;

    // Global - Dark info box
    bool darkInfoBox;

    // Global - 24 hr time
    bool timeTwentyFour;

    // Global - Show desktop Icons
    bool showDesktopIcons;

    // Global - Whether we can open preferences window
    bool canOpenPreferences = true;

    // Global - Clipboard
    Gtk.Clipboard clipboard;

    // Global - Desktop icons
    DesktopIcons desktopIcons;

    // Global - Main container
    Clutter.Actor mainActor;

    // Global - Bubble menu
    BubbleMenu bubbleMenu;

    public class BackgroundWindow : Gtk.Window {

        GtkClutter.Embed embed;

        // Video Wallpaper
        ClutterGst.Playback videoPlayback;
        ClutterGst.Content videoContent;

        // Wallpaper pixbuf & image
        Clutter.Actor wallpaperActor = new Clutter.Actor();
        Pixbuf wallpaperPixbuf;
        Clutter.Image wallpaperImage = new Clutter.Image();

        // Date and time box itself
        DateTimeBox dateTimeBox = new DateTimeBox();

        // Asset Actor
        AssetActor assetActor = new AssetActor();

        // Current animation mode
        bool dateTimeBoxParallax = false;

        // Gradient bg animation (if available)
        string gradientBackground = "";

        const TargetEntry[] targets = {
        { "text/uri-list", 0, 0}
        };


        public BackgroundWindow () {

            title = "Desktop";

            configFilePath = Environment.get_home_dir() + "/.Komorebi.prop";
            configFile = File.new_for_path(configFilePath);
            configKeyFile = new KeyFile ();
            wallpaperKeyFile = new KeyFile ();

            // Get current monitor size
            getMonitorSize();

            embed = new GtkClutter.Embed() {width_request = screenWidth, height_request = screenHeight};
            mainActor = embed.get_stage();
            desktopPath = Environment.get_user_special_dir(UserDirectory.DESKTOP);
            desktopIcons = new DesktopIcons();
            bubbleMenu = new BubbleMenu();

            if(!disableVideo) {
                videoPlayback = new ClutterGst.Playback ();
                videoContent = new ClutterGst.Content();
                videoPlayback.set_seek_flags (ClutterGst.SeekFlags.ACCURATE);

                videoContent.player = videoPlayback;

                videoPlayback.notify["progress"].connect(() => {

                    if(videoPlayback.progress >= 1.0 && wallpaperType == "video") {
                        videoPlayback.progress = 0.0;
                        videoPlayback.playing = true;
                    }

                });
            }


            // Setup widgets
            set_size_request(screenWidth, screenHeight);
            resizable = false;
            set_type_hint(WindowTypeHint.DESKTOP);
            set_keep_below(true);
            app_paintable = false;
            skip_pager_hint = true;
            skip_taskbar_hint = true;
            accept_focus = true;
            stick ();
            decorated = false;
            add_events (EventMask.ENTER_NOTIFY_MASK   |
                        EventMask.POINTER_MOTION_MASK |
                        EventMask.SMOOTH_SCROLL_MASK);
            Gtk.drag_dest_set (this, Gtk.DestDefaults.MOTION | Gtk.DestDefaults.DROP, targets, Gdk.DragAction.MOVE);

            mainActor.background_color = Clutter.Color.from_string("black");

            wallpaperActor.set_size(screenWidth, screenHeight);
            assetActor.set_size(screenWidth, screenHeight);
            clipboard = Gtk.Clipboard.get_for_display (get_display (), Gdk.SELECTION_CLIPBOARD);
            wallpaperActor.set_pivot_point (0.5f, 0.5f);


            // Add widgets
            mainActor.add_child(wallpaperActor);
            mainActor.add_child(dateTimeBox);
            mainActor.add_child(assetActor);
            mainActor.add_child(desktopIcons);
            mainActor.add_child(bubbleMenu);

            add(embed);

            // Properties
            readConfigurationFile();
            initializeConfigFile();
            signalsSetup();

        }

        public bool checkDesktopCompatible() {

            // We're not supporting Wayland at the moment
            // due to some restrictions
            if(Environment.get_variable ("XDG_SESSION_DESKTOP").contains("wayland")) {
                return false;
            }

            return true;
        }

        void getMonitorSize() {

			Rectangle rectangle;
			var screen = Gdk.Screen.get_default ();

            screen.get_monitor_geometry (screen.get_primary_monitor (), out rectangle);

			screenHeight = rectangle.height;
			screenWidth = rectangle.width;

            move(rectangle.x, rectangle.y);

        }

        void signalsSetup () {

            button_release_event.connect((e) => {

                // Hide the bubble menu
                if(bubbleMenu.opacity > 0) {
                    bubbleMenu.fadeOut();
                    unDimWallpaper();
                    return true;
                }

                // Show options
                if(e.button == 3) {

                    if(bubbleMenu.opacity > 0)
                        return false;

                    if(e.x >= desktopIcons.x && e.x <= (desktopIcons.x + desktopIcons.width) &&
                       e.y >= desktopIcons.y && e.y <= (desktopIcons.y + desktopIcons.height))
                        return false;

                    bubbleMenu.fadeIn(e.x, e.y, MenuType.DESKTOP);
                    dimWallpaper();
                }

                return false;
            });

            motion_notify_event.connect((event) => {

                // No parallax when menu is open
                if(bubbleMenu.opacity > 0) {
                    return true;
                }

                var layer_coeff = 70;

                if(dateTimeParallax) {
                    if(dateTimePosition == "center") {
                        dateTimeBox.x = (float)((mainActor.width - dateTimeBox.width) / 2 - (event.x - (mainActor.width / 2)) / layer_coeff);
                        dateTimeBox.y = (float)((mainActor.height - dateTimeBox.height) / 2 - (event.y - (mainActor.height / 2)) / layer_coeff);
                    }
                }

                if(wallpaperParallax) {
                    wallpaperActor.x = (float)((mainActor.width - wallpaperActor.width) / 2 - (event.x - (mainActor.width / 2)) / layer_coeff);
                    wallpaperActor.y = (float)((mainActor.height - wallpaperActor.height) / 2 - (event.y - (mainActor.height / 2)) / layer_coeff);
                }

                return true;
            });

            focus_out_event.connect(() => {

                // Hide the bubble menu
                if(bubbleMenu.opacity > 0) {
                    bubbleMenu.fadeOut();
                    unDimWallpaper();
                    return true;
                }

                return true;
            });

            drag_motion.connect(dimWallpaper);

            drag_leave.connect(() => unDimWallpaper());

            drag_data_received.connect((widget, context, x, y, selectionData, info, time) => {

                foreach(var uri in selectionData.get_uris()) {

                    // Path of the file
                    string filePath = uri.replace("file://","").replace("file:/","");
                    filePath = GLib.Uri.unescape_string (filePath);

                    // Get the actual GLib file
                    var file = File.new_for_path(filePath);
                    var desktopFile = File.new_for_path(desktopPath + "/" + file.get_basename());
                    file.copy(desktopFile, FileCopyFlags.NONE, null);
                }

                Gtk.drag_finish (context, true, false, time);
            });
        }

        public void initializeConfigFile () {

            readWallpaperFile();

            setWallpaper();

            if(!showDesktopIcons)
                desktopIcons.fadeOut();
            else
                desktopIcons.fadeIn();

            if(dateTimeVisible) {

                if(dateTimeAlwaysOnTop)
                    mainActor.set_child_above_sibling(dateTimeBox, assetActor);
                else
                    mainActor.set_child_below_sibling(dateTimeBox, assetActor);

                dateTimeBox.setDateTime();
            } else
                dateTimeBox.fadeOut();

            if(wallpaperType != "video" && assetVisible)
                assetActor.setAsset();
            else
                assetActor.shouldAnimate();
        }

        void setWallpaper() {

            var scaleWidth = screenWidth;
            var scaleHeight = screenHeight;

            if(wallpaperParallax) {
                wallpaperActor.scale_y = 1.05f;
                wallpaperActor.scale_x = 1.05f;
            } else {
                wallpaperActor.scale_y = 1.00f;
                wallpaperActor.scale_x = 1.00f;
            }

            if(wallpaperType == "video") {

                var videoPath = @"file:///opt/Komorebi/$wallpaperName/$videoFileName";
                videoPlayback.uri = videoPath;
                videoPlayback.playing = true;

                wallpaperActor.set_content(videoContent);

                return;
            }

            videoPlayback.playing = false;
            videoPlayback.uri = "";

            wallpaperActor.set_content(wallpaperImage);

            wallpaperPixbuf = new Gdk.Pixbuf.from_file_at_scale(@"/opt/Komorebi/$wallpaperName/wallpaper.jpg",
                                                                scaleWidth, scaleHeight, false);

            wallpaperImage.set_data (wallpaperPixbuf.get_pixels(), Cogl.PixelFormat.RGB_888,
            				 wallpaperPixbuf.get_width(), wallpaperPixbuf.get_height(),
                             wallpaperPixbuf.get_rowstride());
        }

        public bool dimWallpaper () {

            wallpaperActor.save_easing_state ();
            wallpaperActor.set_easing_duration (400);
            wallpaperActor.opacity = 100;
            wallpaperActor.set_easing_mode (Clutter.AnimationMode.EASE_IN_SINE);
            wallpaperActor.restore_easing_state ();

            assetActor.opacity = 0;
            dateTimeBox.opacity = 0;

            return true;
        }

        bool unDimWallpaper () {

            wallpaperActor.save_easing_state ();
            wallpaperActor.set_easing_duration (400);
            wallpaperActor.opacity = 255;
            wallpaperActor.set_easing_mode (Clutter.AnimationMode.EASE_IN_SINE);
            wallpaperActor.restore_easing_state ();

            if(assetVisible)
                assetActor.opacity = 255;
            dateTimeBox.fadeIn(200);

            if(!showDesktopIcons)
                desktopIcons.fadeOut();
            else
                desktopIcons.fadeIn();

            return true;
        }

        /* Shows the window */
        public void fadeIn() {

            show_all();
            dateTimeBox.setPosition();
            desktopIcons.addIconsFromQueue();

        }
    }
}
