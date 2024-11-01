public class SearchResult : Gtk.HBox {
    private Gtk.Image image;
    public string video_id;

    /**
     * @object The Json object returned by the invidious API
    */
    public SearchResult (Json.Object object) {
        this.set_spacing(10);
        // TODO: All the print(error) calls here should be replaced by creating
        // a SearchResult that displays the error
        if (!object.has_member ("type")) {
            print ("Error: result has not type\n");
            return;
        }

        var type_string = object.get_string_member ("type");
        if (type_string != "video") {
            this.error ("Result is not a video");
        } else {
            this.video (object);
        }

        show_all();
    }

    private void error (string message) {
        this.pack_start(new Gtk.Label ("Error:" + message));
    }

    private void video (Json.Object object) {
        var title = object.get_member ("title");
        if (title == null) {
            print ("Error: result has no title\n");
            return;
        }

        if (title.get_node_type () != Json.NodeType.VALUE) {
            print ("Error: title is not a value\n");
            return;
        }

        var title_value = title.get_value ();
        if (!title_value.holds(typeof(string))) {
            print ("Error: title is not a string\n");
            return;
        }

        var title_string = title_value.get_string ();

        string thumb_url = null;
        {
            if (!object.has_member ("videoThumbnails")) {
                print ("No thumbails\n");
                return;
            }

            var thumbnails_array = object.get_array_member ("videoThumbnails");
            foreach (var thumbnail in thumbnails_array.get_elements ()) {
                var thumbnail_object = thumbnail.get_object ();
                var quality = thumbnail_object.get_string_member ("quality");

                if (quality != "default") {
                    continue;
                }

                thumb_url = thumbnail_object.get_string_member ("url");
                break;
            }
        }

        var video_id = object.get_string_member ("videoId");

        this.set_spacing(10);

        var details_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
        this.pack_end(details_box);

        var title_label = new Gtk.Label (null);
        title_label.set_markup ("<b>" + GLib.Markup.escape_text(title_string) + "</b>");
        title_label.halign = Gtk.Align.START;

        details_box.pack_start (title_label);

        var author_string = object.get_string_member ("author");
        var author_label = new Gtk.Label ("By: " + author_string);
        author_label.halign = Gtk.Align.START;
        details_box.pack_start (author_label);

        var views_string = object.get_string_member ("viewCountText");
        var views_label = new Gtk.Label ("Views: " + views_string);
        views_label.halign = Gtk.Align.START;
        details_box.pack_start (views_label);

        show_all ();
        load_thumbnail.begin(thumb_url);

        this.video_id = video_id;
    }

    async void load_thumbnail(string thumb_url) {
        var session = new Soup.Session ();
        var message = new Soup.Message ("GET", thumb_url);

        var stream = yield session.send_async (message);

        var pixbuf = new Gdk.Pixbuf.from_stream (stream);

        this.image = new Gtk.Image.from_pixbuf (pixbuf);
        this.pack_start (this.image, expand = false);
        this.image.show() ;
    }
}

[GtkTemplate(ui = "/net/arthurclho/invplayer/ui/search-page.ui")]
class SearchPage : Gtk.Box {
    [GtkChild]
    private unowned Gtk.SearchEntry search_entry;
    [GtkChild]
    private unowned Gtk.ListBox result_list;

    public signal void video_chosen(string id);

    [GtkCallback]
    void on_search_entry_activate() {
        foreach (var item in result_list.get_children()) {
            result_list.remove(item);
        }
        do_search.begin(search_entry.get_text ());
    }

    [GtkCallback]
    void result_activated(Gtk.ListBoxRow row) {
        var sr = row.get_child() as SearchResult;
        video_chosen(sr.video_id);
    }

    async void do_search(string query) {
        string url = "https://invidious.jing.rocks/api/v1/search?q=" + query;

        var session = new Soup.Session ();
        session.timeout = 10;
        var message = new Soup.Message ("GET", url);

        print ("Sending request: %s\n", url);
        session.queue_message (message, (sess, msg) => {
            print ("Status code: %u\n", msg.status_code);

            var parser = new Json.Parser ();
            try {
                parser.load_from_data ((string) msg.response_body.data);
            } catch (Error e) {
                print ("Error parsing json: %s\n", e.message);
            }

            var node = parser.get_root ();

            if (node.get_node_type () != Json.NodeType.ARRAY) {
                print ("Error: expected array\n");
                return;
            }

            var array = node.get_array ();
            print ("Got %u results\n", array.get_length ());
            foreach (var item in array.get_elements ()) {
                if (item.get_node_type () != Json.NodeType.OBJECT) {
                    print ("Error: expected object\n");
                    return;
                }
                var obj = item.get_object ();
                this.result_list.insert(new SearchResult (obj), -1);
            }
        });
    }
}
