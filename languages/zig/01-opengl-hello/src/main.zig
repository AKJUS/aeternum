const std = @import("std");

const c = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", "");
    @cInclude("GLFW/glfw3.h");
});

const GL = struct {
    glClearColor: *const fn (f32, f32, f32, f32) callconv(.c) void,
    glClear: *const fn (u32) callconv(.c) void,
    glGenVertexArrays: *const fn (i32, *u32) callconv(.c) void,
    glBindVertexArray: *const fn (u32) callconv(.c) void,
    glGenBuffers: *const fn (i32, *u32) callconv(.c) void,
    glBindBuffer: *const fn (u32, u32) callconv(.c) void,
    glBufferData: *const fn (u32, isize, ?*const anyopaque, u32) callconv(.c) void,
    glEnableVertexAttribArray: *const fn (u32) callconv(.c) void,
    glVertexAttribPointer: *const fn (u32, i32, u32, u8, i32, ?*const anyopaque) callconv(.c) void,
    glCreateShader: *const fn (u32) callconv(.c) u32,
    glShaderSource: *const fn (u32, i32, [*]const [*]const u8, ?*const i32) callconv(.c) void,
    glCompileShader: *const fn (u32) callconv(.c) void,
    glGetShaderiv: *const fn (u32, u32, *i32) callconv(.c) void,
    glGetShaderInfoLog: *const fn (u32, i32, ?*i32, [*]u8) callconv(.c) void,
    glCreateProgram: *const fn () callconv(.c) u32,
    glAttachShader: *const fn (u32, u32) callconv(.c) void,
    glLinkProgram: *const fn (u32) callconv(.c) void,
    glGetProgramiv: *const fn (u32, u32, *i32) callconv(.c) void,
    glGetProgramInfoLog: *const fn (u32, i32, ?*i32, [*]u8) callconv(.c) void,
    glUseProgram: *const fn (u32) callconv(.c) void,
    glDeleteShader: *const fn (u32) callconv(.c) void,
    glViewport: *const fn (i32, i32, i32, i32) callconv(.c) void,
    glDrawArrays: *const fn (u32, i32, i32) callconv(.c) void,
};

var gl: GL = undefined;

fn loadGlSymbols() void {
    const struct_info = @typeInfo(GL).@"struct";
    inline for (struct_info.fields) |field| {
        const symbol_name: [:0]const u8 = field.name ++ "\x00";
        const proc = c.glfwGetProcAddress(symbol_name.ptr) orelse {
            std.debug.print("Failed to map symbol: {s}\n", .{field.name});
            std.process.exit(1);
        };
        @field(gl, field.name) = @ptrCast(@alignCast(proc));
    }
}

// GL constants (avoids magic numbers scattered through main)
const GL_ARRAY_BUFFER: u32 = 0x8892;
const GL_STATIC_DRAW: u32 = 0x88E4;
const GL_FLOAT: u32 = 0x1406;
const GL_VERTEX_SHADER: u32 = 0x8B31;
const GL_FRAGMENT_SHADER: u32 = 0x8B30;
const GL_COMPILE_STATUS: u32 = 0x8B81;
const GL_LINK_STATUS: u32 = 0x8B82;
const GL_COLOR_BUFFER_BIT: u32 = 0x4000;
const GL_TRIANGLES: u32 = 0x0004;

fn compileShader(kind: u32, source: [:0]const u8) u32 {
    const shader = gl.glCreateShader(kind);
    const sources = [_][*]const u8{source.ptr};
    gl.glShaderSource(shader, 1, &sources, null);
    gl.glCompileShader(shader);

    var ok: i32 = 0;
    gl.glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (ok == 0) {
        var log: [512]u8 = undefined;
        gl.glGetShaderInfoLog(shader, log.len, null, &log);
        std.debug.print("shader compile error: {s}\n", .{std.mem.sliceTo(&log, 0)});
        std.process.exit(1);
    }
    return shader;
}

pub fn main(init: std.process.Init) !void {
    if (c.glfwInit() == c.GLFW_FALSE) return error.GlfwInitFailed;
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    const window = c.glfwCreateWindow(800, 600, "OpenGL Hello Triangle", null, null) orelse
        return error.WindowInitFailed;
    c.glfwMakeContextCurrent(window);

    loadGlSymbols();

    const vertex_shader_src =
        \\#version 330 core
        \\layout (location = 0) in vec3 aPos;
        \\void main() {
        \\   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
        \\}
    ;

    const fragment_shader_src =
        \\#version 330 core
        \\out vec4 FragColor;
        \\void main() {
        \\   FragColor = vec4(1.0, 0.5, 0.2, 1.0);
        \\}
    ;

    const vertex_shader = compileShader(GL_VERTEX_SHADER, vertex_shader_src);
    const fragment_shader = compileShader(GL_FRAGMENT_SHADER, fragment_shader_src);

    const shader_program = gl.glCreateProgram();
    gl.glAttachShader(shader_program, vertex_shader);
    gl.glAttachShader(shader_program, fragment_shader);
    gl.glLinkProgram(shader_program);

    var link_ok: i32 = 0;
    gl.glGetProgramiv(shader_program, GL_LINK_STATUS, &link_ok);
    if (link_ok == 0) {
        var log: [512]u8 = undefined;
        gl.glGetProgramInfoLog(shader_program, log.len, null, &log);
        std.debug.print("program link error: {s}\n", .{std.mem.sliceTo(&log, 0)});
        std.process.exit(1);
    }

    gl.glDeleteShader(vertex_shader);
    gl.glDeleteShader(fragment_shader);

    const vertices = [_]f32{
        -0.5, -0.5, 0.0,
        0.5,  -0.5, 0.0,
        0.0,  0.5,  0.0,
    };

    var vao: u32 = 0;
    var vbo: u32 = 0;
    gl.glGenVertexArrays(1, &vao);
    gl.glGenBuffers(1, &vbo);

    gl.glBindVertexArray(vao);
    gl.glBindBuffer(GL_ARRAY_BUFFER, vbo);
    gl.glBufferData(GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, GL_STATIC_DRAW);

    gl.glVertexAttribPointer(0, 3, GL_FLOAT, 0, 3 * @sizeOf(f32), null);
    gl.glEnableVertexAttribArray(0);

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        c.glfwPollEvents();

        var width: i32 = 0;
        var height: i32 = 0;
        c.glfwGetFramebufferSize(window, &width, &height);
        gl.glViewport(0, 0, width, height);

        gl.glClearColor(0.15, 0.15, 0.15, 1.0);
        gl.glClear(GL_COLOR_BUFFER_BIT);

        gl.glUseProgram(shader_program);
        gl.glBindVertexArray(vao);
        gl.glDrawArrays(GL_TRIANGLES, 0, 3);

        c.glfwSwapBuffers(window);
    }

    _ = init; // unused; kept for the injected io/gpa if you extend this later
}
