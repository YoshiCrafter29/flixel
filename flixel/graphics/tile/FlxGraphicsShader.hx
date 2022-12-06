package flixel.graphics.tile;

#if FLX_DRAW_QUADS
import openfl.display.GraphicsShader;

class FlxGraphicsShader extends GraphicsShader
{
	@:glVertexSource("
		#pragma header
		
		attribute float alpha;
		attribute vec4 colorMultiplier;
		attribute vec4 colorOffset;
		uniform bool hasColorTransform;
		
		void main(void)
		{
			#pragma body
			
			openfl_Alphav = openfl_Alpha * alpha;
			
			if (hasColorTransform)
			{
				openfl_ColorOffsetv = colorOffset / 255.0;
				openfl_ColorMultiplierv = colorMultiplier;
			}
		}")
	@:glFragmentHeader("
		uniform bool hasTransform;
		uniform bool hasColorTransform;

		vec4 flixel_texture2D(sampler2D bitmap, vec2 coord)
		{
			vec4 color = texture2D(bitmap, coord);
			if (!hasTransform)
			{
				return color;
			}

			if (color.a == 0.0)
			{
				return vec4(0.0, 0.0, 0.0, 0.0);
			}

			if (!hasColorTransform)
			{
				return color * openfl_Alphav;
			}

			color = vec4(color.rgb / color.a, color.a);

			mat4 colorMultiplier = mat4(0);
			colorMultiplier[0][0] = openfl_ColorMultiplierv.x;
			colorMultiplier[1][1] = openfl_ColorMultiplierv.y;
			colorMultiplier[2][2] = openfl_ColorMultiplierv.z;
			colorMultiplier[3][3] = openfl_ColorMultiplierv.w;

			color = clamp(openfl_ColorOffsetv + (color * colorMultiplier), 0.0, 1.0);

			if (color.a > 0.0)
			{
				return vec4(color.rgb * color.a * openfl_Alphav, color.a * openfl_Alphav);
			}
			return vec4(0.0, 0.0, 0.0, 0.0);
		}

		uniform vec4 _camSize;
		
		float map(float value, float min1, float max1, float min2, float max2) {
		  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
		}
		
		vec2 getCamPos(vec2 pos) {
			vec4 size = _camSize / vec4(openfl_TextureSize, openfl_TextureSize);
			return vec2(map(pos.x, size.x, size.x + size.z, 0.0, 1.0), map(pos.y, size.y, size.y + size.w, 0.0, 1.0));
		}
		vec2 camToOg(vec2 pos) {
			vec4 size = _camSize / vec4(openfl_TextureSize, openfl_TextureSize);
			return vec2(map(pos.x, 0.0, 1.0, size.x, size.x + size.z), map(pos.y, 0.0, 1.0, size.y, size.y + size.w));
		}
		vec4 textureCam(sampler2D bitmap, vec2 pos) {
			return flixel_texture2D(bitmap, camToOg(pos));
		}
	")
	@:glFragmentSource("
		#pragma header
		
		void main(void)
		{
			gl_FragColor = flixel_texture2D(bitmap, openfl_TextureCoordv);
		}")
	public function new()
	{
		super();
	}

	public function setCamSize(x:Float, y:Float, width:Float, height:Float)
	{
		data._camSize.value = [x, y, width, height];
	}
}
#end
