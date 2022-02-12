pub fn castTo(comptime T: type, ptr: *anyopaque) *T {
    return @ptrCast(*T, @alignCast(@alignOf(T), ptr));
}

pub fn typeId(comptime T: type) usize {
    _ = T; // We need this line to not have an unused variable error
    
    const static = struct { const bit: u1 = undefined; };
    return @ptrToInt(&static.bit);
}