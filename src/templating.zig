const build = @import("./build.zig");
const std = @import("std");

fn parse_token_style_script(allocator: std.mem.Allocator, line: []const u8, template_path: []const u8) ![]const u8 {
    const token_style: []const u8 = line;
    _ = template_path;
    var allocator_gpa = std.heap.GeneralPurposeAllocator(.{}){};

    defer _ = allocator_gpa.deinit();

    const alloc_gpa = allocator_gpa.allocator();

    const string = try alloc_gpa.alloc(u8, token_style.len);

    defer alloc_gpa.free(string);

    const size = std.mem.replace(u8, token_style, "-", "", string);

    const len_of_string: usize = token_style.len - size;
    const file_content = try alloc_gpa.alloc(u8, 1000000);
    defer alloc_gpa.free(file_content);

    var it = std.mem.splitSequence(u8, string[0..len_of_string], " ");
    while (it.next()) |x| {
        if (std.mem.containsAtLeast(u8, x, 1, "STYLE")) {
            var file_name = it.next().?;

            var dir = try std.fs.cwd().openDir("./site/templates/listed-kevlar-theme", .{});
            defer dir.close();
            file_name = file_name[0 .. file_name.len - 1];

            const style_file = try dir.openFile(file_name, .{});
            defer style_file.close();

            const file_content_size = try style_file.readAll(file_content);

            const style_string = try std.fmt.allocPrint(alloc_gpa, "<style> \n {s} \n</style>", .{file_content[0..file_content_size]});

            defer alloc_gpa.free(style_string);
            const alloc_string = try allocator.alloc(u8, style_string.len);
            std.mem.copyForwards(u8, alloc_string, style_string);
            return alloc_string;
        } else if (std.mem.containsAtLeast(u8, x, 1, "SCRIPT")) {
            var file_name = it.next().?;

            file_name = file_name[0 .. file_name.len - 1];

            var dir = try std.fs.cwd().openDir("./site/templates/listed-kevlar-theme", .{});
            defer dir.close();

            const script_file = try dir.openFile(file_name, .{});
            defer script_file.close();
            const file_content_size = try script_file.readAll(file_content);

            const script_string = try std.fmt.allocPrint(alloc_gpa, "<script> \n {s} \n</script>", .{file_content[0..file_content_size]});

            defer alloc_gpa.free(script_string);
            const alloc_string = try allocator.alloc(u8, script_string.len);
            std.mem.copyForwards(u8, alloc_string, script_string);
            return alloc_string;
        }
    }

    return file_content;
}

fn parse_token(allocator: std.mem.Allocator, line: []const u8, token_type: []const u8, replacement: []const u8) ![]const u8 {
    var new_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = new_alloc.deinit();
    const alloc = new_alloc.allocator();

    const required_size = std.mem.replacementSize(u8, line, token_type, replacement);
    const buffer = try alloc.alloc(u8, required_size);
    defer alloc.free(buffer);
    _ = std.mem.replace(u8, line, token_type, replacement, buffer);
    const replaced_content = try allocator.alloc(u8, buffer.len);
    std.mem.copyForwards(u8, replaced_content, buffer[0..buffer.len]);
    return replaced_content;
}

pub fn parse_post_template(template_path: []const u8, itemsList: build.ListingItem, html_file: std.fs.File) !void {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = allocator.deinit();
    var alloc = allocator.allocator();
    const post_template_path = try std.mem.concat(alloc, u8, &[_][]const u8{ template_path, "/post.html" });
    defer alloc.free(post_template_path);
    const entry_template_path = try std.mem.concat(alloc, u8, &[_][]const u8{ template_path, "/entry.html" });
    defer alloc.free(entry_template_path);

    var file_contents = try alloc.alloc(u8, 1000000);
    defer alloc.free(file_contents);
    var line_size: usize = 0;

    var line = std.ArrayList(u8).init(alloc);
    defer line.deinit();

    const post_template_file = try std.fs.cwd().openFile(post_template_path, .{});
    defer post_template_file.close();

    var buff_reader = std.io.bufferedReader(post_template_file.reader());
    const post_template_reader = buff_reader.reader();
    const writer = line.writer();

    while (post_template_reader.streamUntilDelimiter(writer, '\n', null)) {
        defer line.clearRetainingCapacity();
        const new_line = try std.mem.concat(alloc, u8, &[_][]const u8{ line.items[0..line.items.len], "\n" });
        defer alloc.free(new_line);

        const contains_Title = std.mem.containsAtLeast(u8, new_line, 1, "--TITLE--");
        const contains_Content = std.mem.containsAtLeast(u8, new_line, 1, "--CONTENT--");
        const contains_Header = std.mem.containsAtLeast(u8, new_line, 1, "--HEADER--");
        const contains_Footer = std.mem.containsAtLeast(u8, new_line, 1, "--FOOTER--");
        const contains_Style = std.mem.containsAtLeast(u8, new_line, 1, "--STYLE");
        const contains_Script = std.mem.containsAtLeast(u8, new_line, 1, "--SCRIPT");
        const contains_Listing = std.mem.containsAtLeast(u8, new_line, 1, "--LISTING--");
        // if (contains_Title == true) {
        //
        // } else if (contains_Content == true) {}

        if (contains_Title) {
            const modified_line = try parse_token(alloc, new_line, "--TITLE--", itemsList.lTitle);
            const file_contents_new = try std.mem.concat(alloc, u8, &[_][]const u8{ file_contents[0..line_size], modified_line });
            defer alloc.free(file_contents_new);
            line_size += modified_line.len;
            @memcpy(file_contents[0..line_size], file_contents_new);
            defer alloc.free(modified_line);
        } else if (contains_Content) {
            const modified_line = try parse_token(alloc, new_line, "--CONTENT--", itemsList.lContent);
            const file_contents_new = try std.mem.concat(alloc, u8, &[_][]const u8{ file_contents[0..line_size], modified_line });
            defer alloc.free(file_contents_new);
            line_size += modified_line.len;
            @memcpy(file_contents[0..line_size], file_contents_new);
            defer alloc.free(modified_line);
        } else if (contains_Header) {
            const modified_line = try parse_header_or_footer(alloc, new_line, template_path, itemsList);
            const file_contents_new = try std.mem.concat(alloc, u8, &[_][]const u8{ file_contents[0..line_size], modified_line });
            defer alloc.free(file_contents_new);
            line_size += modified_line.len;
            @memcpy(file_contents[0..line_size], file_contents_new);
            defer alloc.free(modified_line);
        } else if (contains_Footer) {
            const modified_line = try parse_header_or_footer(alloc, new_line, template_path, itemsList);
            const file_contents_new = try std.mem.concat(alloc, u8, &[_][]const u8{ file_contents[0..line_size], modified_line });
            defer alloc.free(file_contents_new);
            line_size += modified_line.len;
            @memcpy(file_contents[0..line_size], file_contents_new);
            defer alloc.free(modified_line);
        } else if (contains_Style) {
            const modified_line = try parse_token_style_script(alloc, new_line, template_path);
            const file_contents_new = try std.mem.concat(alloc, u8, &[_][]const u8{ file_contents[0..line_size], modified_line });
            defer alloc.free(file_contents_new);
            line_size += modified_line.len;
            @memcpy(file_contents[0..line_size], file_contents_new);
        } else if (contains_Script) {
            const modified_line = try parse_token_style_script(alloc, new_line, template_path);
            const file_contents_new = try std.mem.concat(alloc, u8, &[_][]const u8{ file_contents[0..line_size], modified_line });
            defer alloc.free(file_contents_new);
            line_size += modified_line.len;
            @memcpy(file_contents[0..line_size], file_contents_new);
            defer alloc.free(modified_line);
        } else if (contains_Listing) {
            const file_contents_new = try std.mem.concat(alloc, u8, &[_][]const u8{ file_contents[0..line_size], new_line });
            defer alloc.free(file_contents_new);
            line_size += new_line.len;
            @memcpy(file_contents[0..line_size], file_contents_new);
        } else {
            const file_contents_new = try std.mem.concat(alloc, u8, &[_][]const u8{ file_contents[0..line_size], new_line });
            defer alloc.free(file_contents_new);
            line_size += new_line.len;
            @memcpy(file_contents[0..line_size], file_contents_new);
        }
    } else |err| switch (err) {
        error.EndOfStream => {}, // Continue on
        else => return err, // Propagate error
    }

    try html_file.writeAll(file_contents[0..line_size]);
}

pub fn index_file_template(template_path: []const u8, index_file_path: []const u8, itemsList: []build.ListingItem) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var file_contents = try allocator.alloc(u8, 1000000);
    defer allocator.free(file_contents);
    var line_size: usize = 0;

    var line = std.ArrayList(u8).init(allocator);
    defer line.deinit();

    const index_template_file = try std.fs.cwd().openFile(index_file_path, .{});
    defer index_template_file.close();

    var buff_reader = std.io.bufferedReader(index_template_file.reader());
    const index_template_reader = buff_reader.reader();
    const writer = line.writer();
    var order: usize = 0;
    const entry_file_path = try std.mem.join(allocator, "/", &[_][]const u8{ template_path, "entry.html" });
    defer allocator.free(entry_file_path);
    while (index_template_reader.streamUntilDelimiter(writer, '\n', null)) {
        defer line.clearRetainingCapacity();
        const new_line = try std.mem.concat(allocator, u8, &[_][]const u8{ line.items[0..line.items.len], "\n" });
        defer allocator.free(new_line);

        const contains_Title = std.mem.containsAtLeast(u8, new_line, 1, "--TITLE--");
        const contains_Content = std.mem.containsAtLeast(u8, new_line, 1, "--CONTENT--");
        const contains_Header = std.mem.containsAtLeast(u8, new_line, 1, "--HEADER--");
        const contains_Style = std.mem.containsAtLeast(u8, new_line, 1, "--STYLE");
        const contains_Script = std.mem.containsAtLeast(u8, new_line, 1, "--SCRIPT");
        const contains_Listing = std.mem.containsAtLeast(u8, new_line, 1, "--LISTING--");
        const contains_Footer = std.mem.containsAtLeast(u8, new_line, 1, "--FOOTER--");
        if (contains_Title) {
            const modified_line = try parse_token(allocator, new_line, "--TITLE--", itemsList[order].lTitle);
            const file_contents_new = try std.mem.concat(allocator, u8, &[_][]const u8{ file_contents[0..line_size], modified_line });
            defer allocator.free(file_contents_new);
            line_size += modified_line.len;
            order += 1;
            @memcpy(file_contents[0..line_size], file_contents_new);
            defer allocator.free(modified_line);
        } else if (contains_Content) {
            const modified_line = try parse_token(allocator, new_line, "--CONTENT--", itemsList[order].lContent);
            const file_contents_new = try std.mem.concat(allocator, u8, &[_][]const u8{ file_contents[0..line_size], modified_line });
            defer allocator.free(file_contents_new);
            line_size += modified_line.len;
            order += 1;
            @memcpy(file_contents[0..line_size], file_contents_new);
            defer allocator.free(modified_line);
        } else if (contains_Header) {
            const modified_line = try parse_header_or_footer(allocator, new_line, template_path, itemsList[order]);
            const file_contents_new = try std.mem.concat(allocator, u8, &[_][]const u8{ file_contents[0..line_size], modified_line });
            defer allocator.free(file_contents_new);
            line_size += modified_line.len;
            order += 1;
            @memcpy(file_contents[0..line_size], file_contents_new);
            defer allocator.free(modified_line);
        } else if (contains_Footer) {
            const modified_line = try parse_header_or_footer(allocator, new_line, template_path, itemsList[order]);
            const file_contents_new = try std.mem.concat(allocator, u8, &[_][]const u8{ file_contents[0..line_size], modified_line });
            defer allocator.free(file_contents_new);
            line_size += modified_line.len;
            order += 1;
            @memcpy(file_contents[0..line_size], file_contents_new);
            defer allocator.free(modified_line);
        } else if (contains_Style) {
            const modified_line = try parse_token_style_script(allocator, new_line, template_path);
            const file_contents_new = try std.mem.concat(allocator, u8, &[_][]const u8{ file_contents[0..line_size], modified_line });
            defer allocator.free(file_contents_new);
            line_size += modified_line.len;
            order += 1;
            @memcpy(file_contents[0..line_size], file_contents_new);
        } else if (contains_Script) {
            const modified_line = try parse_token_style_script(allocator, new_line, template_path);
            const file_contents_new = try std.mem.concat(allocator, u8, &[_][]const u8{ file_contents[0..line_size], modified_line });
            defer allocator.free(file_contents_new);
            line_size += modified_line.len;
            @memcpy(file_contents[0..line_size], file_contents_new);
            order += 1;
            defer allocator.free(modified_line);
        } else if (contains_Listing) {
            const modified_line = try generate_listing(allocator, entry_file_path, itemsList);

            defer allocator.free(modified_line);
            const file_contents_new = try std.mem.concat(allocator, u8, &[_][]const u8{ file_contents[0..line_size], modified_line });
            defer allocator.free(file_contents_new);
            line_size += modified_line.len;
            @memcpy(file_contents[0..line_size], file_contents_new);
        } else {
            const file_contents_new = try std.mem.concat(allocator, u8, &[_][]const u8{ file_contents[0..line_size], new_line });
            defer allocator.free(file_contents_new);
            line_size += new_line.len;
            order += 1;
            @memcpy(file_contents[0..line_size], file_contents_new);
        } // if (contains_Title == true) {
        //
        // } else if (contains_Content == true) {}
    } else |err| switch (err) {
        error.EndOfStream => {}, // Continue on
        else => return err, // Propagate error
    }
    const index_html_file = try std.fs.cwd().createFile("./site/dist/index.html", .{});
    try index_html_file.writeAll(file_contents[0..line_size]);
    defer index_html_file.close();
}

pub fn generate_listing(allocator: std.mem.Allocator, entry_file_path: []const u8, itemsList: []build.ListingItem) ![]u8 {
    var listing_size: usize = 0;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gpa_alloc = gpa.allocator();

    const entry_file = try std.fs.cwd().openFile(entry_file_path, .{});
    const entry_file_content_buffer = try gpa_alloc.alloc(u8, 100000);
    defer gpa_alloc.free(entry_file_content_buffer);

    const entry_file_size = try entry_file.read(entry_file_content_buffer);

    const listing_content_template = try allocator.alloc(u8, 100000);

    for (itemsList) |item| {
        var list_size: usize = 0;
        const listing_alloc = try gpa_alloc.alloc(u8, 100000);
        defer gpa_alloc.free(listing_alloc);
        var iter_path = std.mem.splitSequence(u8, item.lPath.?, "/");
        _ = iter_path.next().?;
        _ = iter_path.next().?;
        _ = iter_path.next().?;
        const file_path_alloc = try allocator.alloc(u8, 1024);
        defer allocator.free(file_path_alloc);
        std.mem.copyForwards(u8, file_path_alloc, "./");
        var size_of_file_path: usize = 2;

        while (iter_path.peek() != null) {
            const dir_or_file_name = iter_path.peek().?;
            if (std.mem.containsAtLeast(u8, dir_or_file_name, 1, ".")) {
                std.mem.copyBackwards(u8, file_path_alloc[size_of_file_path..], dir_or_file_name);

                size_of_file_path += dir_or_file_name.len;
            } else {
                const dir_name = try std.mem.concat(allocator, u8, &[_][]const u8{ dir_or_file_name, "/" });
                defer allocator.free(dir_name);
                std.mem.copyBackwards(u8, file_path_alloc[size_of_file_path..], dir_name);
                size_of_file_path += dir_name.len;
            }
            _ = iter_path.next();
        }
        std.mem.copyForwards(u8, listing_alloc, entry_file_content_buffer[0..entry_file_size]);
        const contains_Path = std.mem.containsAtLeast(u8, entry_file_content_buffer[0..entry_file_size], 1, "--PATH--");
        const contains_Title = std.mem.containsAtLeast(u8, entry_file_content_buffer[0..entry_file_size], 1, "--TITLE--");
        list_size = entry_file_size;
        if (contains_Path) {
            const replaced_content = try parse_token(gpa_alloc, listing_alloc[0..list_size], "--PATH--", file_path_alloc[0..size_of_file_path]);
            defer gpa_alloc.free(replaced_content);
            list_size = replaced_content.len;
            std.mem.copyForwards(u8, listing_alloc[0..list_size], replaced_content);
            std.mem.copyForwards(u8, listing_content_template[listing_size .. listing_size + list_size], listing_alloc[0..list_size]);
        }
        if (contains_Title) {
            const replaced_content = try parse_token(gpa_alloc, listing_alloc[0..list_size], "--TITLE--", item.lTitle);
            defer gpa_alloc.free(replaced_content);
            list_size = replaced_content.len;
            std.mem.copyForwards(u8, listing_alloc[0..list_size], replaced_content);
            std.mem.copyForwards(u8, listing_content_template[listing_size .. listing_size + list_size], listing_alloc[0..list_size]);
        }
        listing_size += list_size;
    }

    defer allocator.free(listing_content_template);
    const listing_content = try allocator.alloc(u8, listing_size);

    @memcpy(listing_content, listing_content_template[0..listing_size]);

    return listing_content;
}

fn parse_header_or_footer(
    allocator: std.mem.Allocator,
    line: []const u8,
    template_path: []const u8,
    itemList: build.ListingItem,
) ![]const u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const is_Header = std.mem.containsAtLeast(u8, line, 1, "--HEADER--");
    const is_Footer = std.mem.containsAtLeast(u8, line, 1, "--FOOTER--");

    var file_path: ?[]u8 = null;
    if (is_Header) {
        file_path = try std.mem.concat(alloc, u8, &[_][]const u8{ template_path, "/header.html" });
    } else if (is_Footer) {
        file_path = try std.mem.concat(alloc, u8, &[_][]const u8{ template_path, "/footer.html" });
    }
    defer alloc.free(file_path.?);

    const header_or_footer_path = try std.fs.cwd().openFile(file_path.?, .{});
    defer header_or_footer_path.close();
    // const file_content = try alloc.alloc(u8, 100000);
    var buffered_reader = std.io.bufferedReader(header_or_footer_path.reader());
    const header_footer_template_reader = buffered_reader.reader();

    var line_content = std.ArrayList(u8).init(alloc);

    const write = line_content.writer();
    defer line_content.deinit();

    const file_content: []u8 = try alloc.alloc(u8, 1000000);
    defer alloc.free(file_content);
    var size_of_file: usize = 0;

    while (header_footer_template_reader.streamUntilDelimiter(write, '\n', null)) {
        defer line_content.clearRetainingCapacity();
        const line_content_slice = line_content.items[0..line_content.items.len];

        const line_content_slice_return = try std.mem.concat(alloc, u8, &[_][]const u8{ line_content_slice, "\n" });
        defer alloc.free(line_content_slice_return);
        const contains_Title = std.mem.containsAtLeast(u8, line_content_slice_return, 1, "--TITLE--");
        const contains_Content = std.mem.containsAtLeast(u8, line_content_slice_return, 1, "--CONTENT--");
        const contains_Style = std.mem.containsAtLeast(u8, line_content_slice_return, 1, "--STYLE");
        const contains_Script = std.mem.containsAtLeast(u8, line_content_slice_return, 1, "--SCRIPT");
        if (contains_Title) {
            const contents = try parse_token(alloc, line_content_slice_return, "--TITLE--", itemList.lTitle);

            defer alloc.free(contents);

            const file_content_new = try std.mem.concat(alloc, u8, &[_][]const u8{ file_content[0..size_of_file], contents });
            size_of_file += contents.len;
            std.mem.copyForwards(u8, file_content[0..size_of_file], file_content_new[0..]);
            defer alloc.free(file_content_new);
        } else if (contains_Content) {
            const contents = try parse_token(alloc, line_content_slice_return, "--CONTENT--", itemList.lContent);
            defer alloc.free(contents);

            const file_content_new = try std.mem.concat(alloc, u8, &[_][]const u8{ file_content[0..size_of_file], contents });
            size_of_file += contents.len;
            std.mem.copyForwards(u8, file_content, file_content_new[0..]);
            defer alloc.free(file_content_new);
        } else if (contains_Style) {
            const contents = try parse_token_style_script(alloc, line_content_slice_return, template_path);
            defer alloc.free(contents);

            const file_content_new = try std.mem.concat(alloc, u8, &[_][]const u8{ file_content[0..size_of_file], contents });
            size_of_file += contents.len;
            std.mem.copyForwards(u8, file_content, file_content_new[0..]);
            defer alloc.free(file_content_new);
        } else if (contains_Script) {
            const contents = try parse_token_style_script(alloc, line_content_slice_return, template_path);
            defer alloc.free(contents);
            const file_content_new = try std.mem.concat(alloc, u8, &[_][]const u8{ file_content[0..size_of_file], contents });
            size_of_file += contents.len;
            std.mem.copyForwards(u8, file_content, file_content_new[0..]);
            defer alloc.free(file_content_new);
        } else {
            const content = try std.mem.concat(alloc, u8, &[_][]const u8{ file_content[0..size_of_file], line_content_slice_return });
            std.mem.copyForwards(u8, file_content[0..], content);

            defer alloc.free(content);

            size_of_file += line_content_slice_return.len;

            std.mem.copyForwards(u8, file_content, content);
        }
    } else |err| switch (err) {
        error.EndOfStream => {}, // Continue on
        else => return err, // Propagate error
    }

    const file_content_new = try allocator.alloc(u8, size_of_file);

    std.mem.copyForwards(u8, file_content_new, file_content[0..size_of_file]);
    return file_content_new;
}
