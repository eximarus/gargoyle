pub const Quat = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub inline fn new(x: f32, y: f32, z: f32, w: f32) Quat {
        return Quat{ .x = x, .y = y, .z = z, .w = w };
    }
};
