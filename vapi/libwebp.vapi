[CCode (cheader_filename = "webp/decode.h,webp/encode.h")]
namespace WebP {
	public struct BitstreamFeatures {
		public int width;
		public int height;
		public bool has_alpha;
		public bool has_information;
		public int format;
		public int no_incremental_decoding;
		public int rotate;
		public int uv_sampling;
		public uint32 pad[2];
	}
	
	[CCode (cname = "VP8StatusCode", cprefix = "VP8_STATUS_")]
	public enum StatusCode {
		OK = 0,
		OUT_OF_MEMORY,
		INVALID_PARAM,
		BITSTREAM_ERROR,
		UNSUPPORTED_FEATURE,
		SUSPENDED,
		USER_ABORT,
		NOT_ENOUGH_DATA;
		
		public string to_string() {
			var strv = new string[]{
				"VP8_STATUS_OK",
				"VP8_STATUS_OUT_OF_MEMORY",
				"VP8_STATUS_INVALID_PARAM",
				"VP8_STATUS_BITSTREAM_ERROR",
				"VP8_STATUS_UNSUPPORTED_FEATURE",
				"VP8_STATUS_SUSPENDED",
				"VP8_STATUS_USER_ABORT",
				"VP8_STATUS_NOT_ENOUGH_DATA"
			};
			return strv[(int)this];
		}
	}
	
	[CCode (cname = "WebPGetFeatures")]
	public static StatusCode get_features (uint8[] data, out BitstreamFeatures features);
	
	[CCode (cname = "WebPDecodeRGBA", array_length = false)]
	public static uint8[] decode_rgba (uint8[] data, out int width, out int height);
	
	[CCode (cname = "WebPDecodeRGB", array_length = false)]
	public static uint8[] decode_rgb (uint8[] data, out int width, out int height);
	
	[CCode (cname = "WebPEncodeRGB", instance_pos = -1)]
	public static uint8[] encode_rgb ([CCode (array_length = false)] uint8[] data, int width, int height, int stride, float quality);
}

