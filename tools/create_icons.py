from pathlib import Path
from PIL import Image, ImageDraw

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
for name, fn in [('protect',lock),('unlock',unlock),('abandon',trash),('group',group),('dungeon',dungeon),('pvp',pvp)]: render(name,fn)
