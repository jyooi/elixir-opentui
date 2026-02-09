// Minimal ansi.zig stub for standalone textarea build.
// Only contains types referenced by buffer.zig (RGBA, TextAttributes).

pub const RGBA = [4]f32;

pub const TextAttributes = struct {
    pub const NONE: u8 = 0;
    pub const BOLD: u8 = 1 << 0;
    pub const DIM: u8 = 1 << 1;
    pub const ITALIC: u8 = 1 << 2;
    pub const UNDERLINE: u8 = 1 << 3;
    pub const BLINK: u8 = 1 << 4;
    pub const INVERSE: u8 = 1 << 5;
    pub const HIDDEN: u8 = 1 << 6;
    pub const STRIKETHROUGH: u8 = 1 << 7;

    // Constants for attribute bit packing
    pub const ATTRIBUTE_BASE_BITS: u5 = 8;
    pub const ATTRIBUTE_BASE_MASK: u32 = 0xFF;

    // Constants for link_id packing (bits 8-31)
    pub const LINK_ID_BITS: u8 = 24;
    pub const LINK_ID_SHIFT: u5 = ATTRIBUTE_BASE_BITS;
    pub const LINK_ID_PAYLOAD_MASK: u32 = ((@as(u32, 1) << LINK_ID_BITS) - 1);
    pub const LINK_ID_MASK: u32 = LINK_ID_PAYLOAD_MASK << LINK_ID_SHIFT;

    /// Extract the base 8 bits of attributes from a u32 attribute value
    pub fn getBaseAttributes(attr: u32) u8 {
        return @intCast(attr & ATTRIBUTE_BASE_MASK);
    }

    /// Extract the link_id from bits 8-31 of attributes
    pub fn getLinkId(attr: u32) u32 {
        return (attr & LINK_ID_MASK) >> LINK_ID_SHIFT;
    }

    /// Set the link_id in an attribute value, preserving base attributes
    pub fn setLinkId(attr: u32, link_id: u32) u32 {
        const base = attr & ATTRIBUTE_BASE_MASK;
        const link_bits = (link_id & LINK_ID_PAYLOAD_MASK) << LINK_ID_SHIFT;
        return base | link_bits;
    }

    /// Check if an attribute value has a link
    pub fn hasLink(attr: u32) bool {
        return getLinkId(attr) != 0;
    }
};
