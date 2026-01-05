#!/usr/bin/env python3
"""
Convert Disney park SVG icons to tinted PNGs for Pixlet.
Requires: cairosvg, pillow (or use ImageMagick manually)
"""
import os
import sys
import subprocess

PARKS = {
    "animal-kingdom": "#8BC34A",  # Light Green
    "magic-kingdom": "#5EADFF",   # Light Blue
    "epcot": "#00E5FF",           # Cyan
    "hollywood-studios": "#FFD700", # Gold
}

def convert_with_cairosvg():
    """Try using cairosvg + pillow"""
    try:
        import cairosvg
        from PIL import Image
        import io
        
        for park_name, color in PARKS.items():
            svg_path = f"icons/{park_name}.svg"
            png_path = f"icons/{park_name}.png"
            
            if not os.path.exists(svg_path):
                print(f"Warning: {svg_path} not found")
                continue
            
            # Convert SVG to PNG (48x48)
            png_data = cairosvg.svg2png(url=svg_path, output_width=48, output_height=48)
            img = Image.open(io.BytesIO(png_data))
            
            # Force convert to RGBA (no palette)
            img = img.convert("RGBA")
            
            # Create a new RGBA image to ensure no palette
            new_img = Image.new("RGBA", img.size, (0, 0, 0, 0))
            pixels = img.load()
            new_pixels = new_img.load()
            
            # Parse hex color
            r = int(color[1:3], 16)
            g = int(color[3:5], 16)
            b = int(color[5:7], 16)
            
            # Tint: replace non-transparent pixels with park color
            for y in range(img.height):
                for x in range(img.width):
                    r_orig, g_orig, b_orig, a = pixels[x, y]
                    if a > 0:  # Non-transparent
                        new_pixels[x, y] = (r, g, b, a)
                    else:
                        new_pixels[x, y] = (0, 0, 0, 0)
            
            # Save as truecolor RGBA PNG
            new_img.save(png_path, "PNG")
            print(f"✓ Created {png_path} (RGBA, {new_img.size[0]}x{new_img.size[1]})")
        
        return True
    except ImportError:
        return False

def convert_with_imagemagick():
    """Try using ImageMagick via command line to create truecolor RGBA PNGs"""
    try:
        for park_name, color in PARKS.items():
            svg_path = f"icons/{park_name}.svg"
            png_path = f"icons/{park_name}.png"
            
            if not os.path.exists(svg_path):
                print(f"Warning: {svg_path} not found")
                continue
            
            # Use ImageMagick to convert SVG to RGBA PNG, then tint
            # First convert to RGBA PNG
            cmd1 = [
                "convert",
                svg_path,
                "-resize", "48x48",
                "-background", "none",
                "-alpha", "on",
                "PNG32:" + png_path
            ]
            subprocess.run(cmd1, check=True, capture_output=True)
            
            # Then tint with park color (replace black with park color)
            cmd2 = [
                "convert",
                png_path,
                "-fill", color,
                "-colorize", "100%",
                "-type", "TrueColorAlpha",
                png_path
            ]
            subprocess.run(cmd2, check=True, capture_output=True)
            print(f"✓ Created {png_path}")
        
        return True
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"ImageMagick error: {e}")
        return False

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    
    print("Converting park SVGs to tinted PNGs...")
    
    # Try ImageMagick first (more reliable for RGBA)
    if convert_with_imagemagick():
        print("\n✓ All icons converted successfully!")
    elif convert_with_cairosvg():
        print("\n✓ All icons converted successfully!")
    else:
        print("\n✗ No conversion method available.")
        print("\nTo convert manually:")
        print("1. Install: pip install cairosvg pillow")
        print("   OR use ImageMagick: brew install imagemagick")
        print("2. Run this script again")
        print("\nOr convert manually with ImageMagick:")
        for park_name, color in PARKS.items():
            print(f"  convert icons/{park_name}.svg -resize 48x48 -fill {color} -colorize 100% icons/{park_name}.png")
        sys.exit(1)

