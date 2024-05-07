const std = @import("std");
const template = @import("./templating.zig");
const c_md = @cImport({
    @cInclude("md4c-html.h");
    @cInclude("md4c.h");
});

const CONFIG_MAX_PATH_SIZE: comptime_int = 512;
const CONFIG_MAX_FILE_CONTENT: comptime_int = 1000000;

pub const ListingItem = struct {
    lTitle: []u8,
    lContent: []u8,
    lPath: ?[]const u8,
    lOrder: ?u32,
};

const KevlarSkeleton = struct {
    skel_template_folder_path: []const u8,
    skel_posts_folder_path: []const u8,
    skel_dist_path: []const u8,
};

pub fn process_output(html_output: [*c]const u8, size: c_md.MD_SIZE, _: ?*anyopaque) callconv(.C) void {
    const l_size = @as(usize, size);

    var html_str: [*c]const u8 = @ptrCast(html_output[0..l_size]);
    const html_str_new = html_str[0..l_size];

    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = alloc.deinit();
    const str = alloc.allocator().alloc(u8, l_size) catch unreachable;

    defer alloc.allocator().free(str);

    std.mem.copyForwards(u8, str, html_str_new);

    const temp_file = std.fs.cwd().createFile("./temp.html", .{ .truncate = false }) catch unreachable;

    temp_file.seekFromEnd(0) catch unreachable;
    const letter = html_str_new[0..l_size];

    _ = temp_file.write(letter) catch unreachable;
    defer temp_file.close();
}

pub fn count_files_in_folders() !usize {
    const curr_dir = try std.fs.cwd().openDir("./site/posts", .{ .access_sub_paths = true, .iterate = true });
    var number_of_posts: usize = 0;
    var iter = curr_dir.iterate();
    while (true) {
        const entry = try iter.next();
        if (entry == null) {
            break;
        } else {
            switch (entry.?.kind) {
                .file => number_of_posts += 1,
                else => {},
            }
        }
    }
    return number_of_posts;
}

pub fn parse_md_file_to_html(alloc: std.mem.Allocator, folder_path: []const u8, dist_path: []const u8, template_path: []const u8, itemsList: *[]ListingItem) !void {
    var post_count: usize = 0;
    var string_alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_alloc.deinit();
    var allocator = string_alloc.allocator();
    var post_dir = try std.fs.cwd().openDir(folder_path, .{ .iterate = true });
    defer post_dir.close();
    var dir_iter = post_dir.iterate();

    while (true) {
        const entry = try dir_iter.next();
        if (entry == null) {
            break;
        } else {
            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            defer _ = gpa.deinit();
            const title_len = @as(usize, entry.?.name.len - 3);
            const string = try allocator.alloc(u8, title_len);
            defer allocator.free(string);

            const order: u32 = @intCast(post_count);

            std.mem.copyForwards(u8, string, entry.?.name[0..title_len]);
            const new_Title = try alloc.alloc(u8, string.len);
            @memcpy(new_Title, string);

            itemsList.*[post_count].lTitle = new_Title;
            itemsList.*[post_count].lOrder = order;

            var dest_dir = try std.fs.cwd().openDir(dist_path, .{});

            defer dest_dir.close();
            const str_file_name = try std.mem.concat(allocator, u8, &[_][]const u8{ entry.?.name[0 .. entry.?.name.len - 3], ".html" });
            defer allocator.free(str_file_name);

            var post_file = try post_dir.openFile(entry.?.name, .{});

            var file_content = try gpa.allocator().alloc(u8, CONFIG_MAX_FILE_CONTENT);

            defer gpa.allocator().free(file_content);

            const size = try post_file.pread(file_content, 0);

            const exact_file_content = try gpa.allocator().alloc(u8, size);
            defer gpa.allocator().free(exact_file_content);

            const file_content_ptr: []const u8 = @ptrCast(file_content[0..size]);
            std.mem.copyForwards(u8, exact_file_content, file_content_ptr);

            const c_str: [*c]const u8 = @ptrCast(exact_file_content);
            const c_len: c_uint = @intCast(size);

            const k: c_uint = 0;
            _ = c_md.md_html(c_str, c_len, process_output, null, k, k);

            const html_md_buffer = try allocator.alloc(u8, CONFIG_MAX_FILE_CONTENT);
            defer allocator.free(html_md_buffer);

            const temp_file = try std.fs.cwd().openFile("./temp.html", .{});

            const max_len_file = try temp_file.read(html_md_buffer);
            defer temp_file.close();

            try std.fs.cwd().deleteFile("./temp.html");

            var html_file = try dest_dir.createFile(str_file_name, .{});
            // try html_file.writeAll(html_md_buffer[0..max_len_file]);

            const file_location_cwd = try std.mem.concat(allocator, u8, &[_][]const u8{ dist_path, "/", str_file_name });
            defer allocator.free(file_location_cwd);

            const new_file_loc_str = try alloc.alloc(u8, file_location_cwd.len);
            @memcpy(new_file_loc_str, file_location_cwd);

            itemsList.*[post_count].lPath = new_file_loc_str;

            const mem_buffer = try allocator.alloc(u8, max_len_file);
            defer allocator.free(mem_buffer);
            std.mem.copyForwards(u8, mem_buffer, html_md_buffer[0..max_len_file]);
            itemsList.*[post_count].lContent = mem_buffer;

            const post_path = try std.mem.concat(allocator, u8, &[_][]const u8{ template_path, "/post.html" });
            defer allocator.free(post_path);

            defer html_file.close();
            try template.parse_post_template(template_path, itemsList.*[post_count], html_file);
            post_count += 1;
        }
    }
}

fn generate_index_file_from_template(alloc: std.mem.Allocator, folder_path: []const u8, itemList: []ListingItem) !void {
    const y = try std.mem.join(alloc, "/", &[_][]const u8{ folder_path, "index.html" });

    try template.index_file_template(folder_path, y, itemList);
}

pub fn build() !void {
    _ = KevlarSkeleton{ .skel_posts_folder_path = "./site/posts", .skel_template_folder_path = "./site/template", .skel_dist_path = "./site/dist" };
    //const count_md = try count_files_in_folders();
    var arena_alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_alloc.deinit();

    const allocator = arena_alloc.allocator();
    // const list = ListingItem{
    //     .lTitle = undefined,
    //     .lContent = undefined,
    //     .lPath = undefined,
    //     .lOrder = undefined,
    // };

    var itemsList = try allocator.alloc(ListingItem, try count_files_in_folders());

    try parse_md_file_to_html(allocator, "./site/posts", "./site/dist", "./site/templates/listed-kevlar-theme", &itemsList);
    try generate_index_file_from_template(allocator, "./site/templates/listed-kevlar-theme", itemsList);
}
