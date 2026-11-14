from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import random

OUT = Path(__file__).resolve().parent.parent / 'Icons'
OUT.mkdir(exist_ok=True)
S = 4

def render(name, draw_icon):
    im = Image.new('RGBA', (64*S, 64*S))
    d = ImageDraw.Draw(im)
    def line(points, fill, width=3): d.line([(x*S,y*S) for x,y in points], fill=fill, width=width*S, joint='curve')
    def ellipse(box, fill): d.ellipse(tuple(x*S for x in box), fill=fill)
    def polygon(points, fill): d.polygon([(x*S,y*S) for x,y in points], fill=fill)
    draw_icon(line, ellipse, polygon)
    im.resize((64,64), Image.Resampling.LANCZOS).save(OUT / (name+'.tga'), compression=None)

ivory = (235, 225, 199, 255)
gold = (242, 195, 80, 255)
def lock(line, ellipse, polygon):
    line([(21,29),(21,21),(23,14),(28,10),(36,10),(41,14),(43,21),(43,29)], ivory, 5)
    polygon([(17,28),(47,28),(47,53),(17,53)], ivory)
    ellipse((29,34,35,40),(24,25,31,255)); line([(32,39),(32,46)],(24,25,31,255),3)
def trash(line, ellipse, polygon):
    ellipse((8,8,56,56),(160,45,37,255))
    ellipse((12,12,52,52),(78,24,21,255))
    line([(22,22),(42,42)],ivory,5); line([(42,22),(22,42)],ivory,5)
def unlock(line, ellipse, polygon):
    line([(21,29),(21,21),(23,14),(28,10),(36,10),(41,14)], ivory, 5)
    polygon([(17,28),(47,28),(47,53),(17,53)], ivory)
    ellipse((29,34,35,40),(24,25,31,255)); line([(32,39),(32,46)],(24,25,31,255),3)
def group(line, ellipse, polygon):
    ellipse((24,9,40,25),gold); ellipse((7,16,19,28),ivory); ellipse((45,16,57,28),ivory)
    polygon([(18,52),(19,38),(23,31),(29,28),(35,28),(41,31),(45,38),(46,52)],gold)
    polygon([(4,48),(5,37),(9,31),(17,31),(20,34),(15,41),(15,48)],ivory)
    polygon([(49,48),(49,41),(44,34),(47,31),(55,31),(59,37),(60,48)],ivory)
def dungeon(line, ellipse, polygon):
    polygon([(10,54),(10,23),(17,23),(17,15),(25,15),(25,23),(39,23),(39,15),(47,15),(47,23),(54,23),(54,54)],ivory)
    polygon([(24,54),(24,40),(26,34),(30,31),(34,31),(38,34),(40,40),(40,54)],(24,25,31,255))
def pvp(line, ellipse, polygon):
    line([(15,13),(48,49)],ivory,5); line([(49,13),(16,49)],ivory,5)
    line([(10,15),(18,8),(22,23),(13,20)],gold,3); line([(54,15),(46,8),(42,23),(51,20)],gold,3)
    line([(10,42),(22,53)],gold,4); line([(54,42),(42,53)],gold,4)
def raid(line, ellipse, polygon):
    polygon([(12,13),(52,13),(50,39),(43,49),(32,56),(21,49),(14,39)],gold)
    polygon([(17,18),(47,18),(45,37),(39,44),(32,49),(25,44),(19,37)],(55,38,23,255))
    line([(23,32),(41,32)],ivory,3); line([(32,23),(32,41)],ivory,3)
def sort_icon(line, ellipse, polygon):
    line([(16,14),(16,49)],ivory,4); polygon([(8,41),(16,52),(24,41)],ivory)
    line([(30,18),(54,18)],gold,4); line([(30,30),(48,30)],gold,4); line([(30,42),(42,42)],gold,4)
def all_icon(line, ellipse, polygon):
    for x in (12,29,46):
        for y in (13,30,47): ellipse((x-4,y-4,x+4,y+4),ivory)
def low_icon(line, ellipse, polygon):
    line([(16,14),(16,48)],ivory,4); polygon([(7,39),(16,52),(25,39)],ivory)
    line([(35,20),(54,20)],gold,4); line([(35,32),(49,32)],gold,4)
def zero_icon(line, ellipse, polygon):
    ellipse((14,8,50,56),ivory); ellipse((20,14,44,50),(35,27,19,255))
def complete_icon(line, ellipse, polygon):
    line([(12,33),(26,47),(53,17)],gold,6)
def waypoint_icon(line, ellipse, polygon):
    ellipse((12,6,52,46),gold)
    polygon([(14,28),(50,28),(32,58)],gold)
    ellipse((25,18,39,32),(45,30,18,255))
def active_icon(line, ellipse, polygon):
    polygon([(14,9),(45,9),(50,14),(50,55),(14,55)],gold)
    polygon([(19,14),(44,14),(44,50),(19,50)],(52,35,20,255))
    line([(24,23),(39,23)],ivory,3); line([(24,31),(39,31)],ivory,3); line([(24,39),(35,39)],ivory,3)
def forever_icon(line, ellipse, polygon):
    line([(32,32),(25,24),(19,22),(13,24),(10,29),(10,35),(13,40),(19,42),(25,40),(32,32),(39,24),(45,22),(51,24),(54,29),(54,35),(51,40),(45,42),(39,40),(32,32)],(112,220,231,255),5)
def class_icon(line, ellipse, polygon):
    polygon([(12,12),(52,12),(49,39),(42,49),(32,56),(22,49),(15,39)],gold)
    polygon([(17,17),(47,17),(44,37),(39,44),(32,49),(25,44),(20,37)],(55,38,23,255))
    ellipse((26,20,38,32),ivory); polygon([(22,43),(23,37),(27,33),(37,33),(41,37),(42,43)],ivory)
def profession_icon(line, ellipse, polygon):
    line([(22,48),(43,20)],ivory,6)
    polygon([(31,12),(43,9),(53,18),(47,24),(40,20),(35,24),(27,20)],gold)
    line([(14,51),(25,40)],gold,4)
for name, fn in [('protect',lock),('unlock',unlock),('abandon',trash),('group',group),('dungeon',dungeon),('pvp',pvp),('raid',raid),('sort',sort_icon),('all',all_icon),('low',low_icon),('zero',zero_icon),('complete',complete_icon),('waypoint',waypoint_icon),('active',active_icon),('forever',forever_icon),('class',class_icon),('profession',profession_icon)]: render(name,fn)

# Use the dedicated circular artwork without the square add-on icon's frame.
source = Image.open(OUT.parent / 'docs' / 'assets' / 'medallion-512.png').convert('RGBA')
source.resize((128, 128), Image.Resampling.LANCZOS).save(OUT / 'medallion.tga', compression=None)

# Warm, softly mottled leather-like title bar, independent of client assets.
rng = random.Random(20261114)
grain = Image.new('L', (512, 64))
grain.putdata([rng.randrange(256) for _ in range(512 * 64)])
coarse = grain.resize((64, 8), Image.Resampling.BOX).resize((512, 64), Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(5))
fine = grain.filter(ImageFilter.GaussianBlur(1.4))
texture = Image.new('RGB', (512, 64))
pixels = []
for y in range(64):
    for x in range(512):
        tone = (coarse.getpixel((x, y)) - 128) * 0.8 + (fine.getpixel((x, y)) - 128) * 0.22 + (0.5 - y / 63) * 7
        pixels.append((max(0, min(255, round(110 + tone))), max(0, min(255, round(63 + tone * 0.75))), max(0, min(255, round(39 + tone * 0.55)))))
texture.putdata(pixels)
texture.save(OUT / 'titlebar.tga', compression=None)
