"""Finite world-aligned whole material domains; no cell-edge clipping."""
from PIL import Image

def selected_ids(roads,entry):
    cells={(int(x),int(y)) for x,y,*_ in roads};selected=set()
    for x,y in sorted(cells):
        c=entry['cells'][y][x];selected.update(c['anchors']);selected.add(c['center'])
        for direction,dx,dy in [('N',0,-1),('E',1,0),('S',0,1),('W',-1,0)]:
            if (x+dx,y+dy) in cells:selected.update(c[direction])
    return sorted(selected)

def compose(roads,atlas,entry):
    out=Image.new('RGBA',(768,576));ox,oy,_,_=entry['region']
    for ident in selected_ids(roads,entry):
        for y,x,w in entry['components'][ident]['runs']:
            out.paste(atlas.crop((ox+x,oy+y,ox+x+w,oy+y+1)),(x,y))
    return out
