"""Render one validated Eightfold layout from the delivered atlas, without rebuilding art."""
import argparse, json, math
from pathlib import Path
from PIL import Image
from export_ground import C, render, road_layer, connected_material

def validate(data, contract):
    def ints(a,n):
        return isinstance(a,list) and len(a)==n and all(type(v) in [int,float] and math.isfinite(v) and int(v)==v for v in a)
    if not isinstance(data,dict) or data.get('schema')!='eightfold.layout/1.1' or data.get('size')!=[24,18]:
        raise ValueError('Expected an Eightfold 24 x 18 layout.')
    themes={t['id'] for t in contract['themes']}
    if data.get('theme') not in themes:raise ValueError('Unknown theme.')
    for name in ['roads','stamps','decorations','fixedLayers']:
        if not isinstance(data.get(name),list):raise ValueError('Missing list: '+name)
    policy=data.get('materialField')
    if policy is not None and (not isinstance(policy,dict) or type(policy.get('enabled')) is not bool or policy.get('version') not in ['1.12','1.13','1.14','1.15','1.16']):
        raise ValueError('Unknown material policy; use version 1.12, 1.13, 1.14, 1.15 or 1.16.')
    seen=set()
    for a in data['roads']:
        if not ints(a,3) or not 0<=a[0]<24 or not 0<=a[1]<18 or not 0<=a[2]<8 or tuple(a[:2]) in seen:raise ValueError('Invalid/duplicate road cell.')
        seen.add(tuple(a[:2]))
    for a in data['stamps']:
        if not isinstance(a,list) or len(a)!=3 or a[0] not in contract['components'] or not ints(a[1:],2):raise ValueError('Invalid whole component.')
        r=contract['components'][a[0]]['region']
        if a[1]<0 or a[2]<0 or a[1]+r[2]>768 or a[2]+r[3]>576:raise ValueError('Component outside canvas.')
    for a in data['decorations']:
        if not ints(a,3) or not 0<=a[0]<6 or not 0<=a[1]<=736 or not 0<=a[2]<=544:raise ValueError('Invalid decoration.')
    for layer in data['fixedLayers']:
        if not isinstance(layer,dict) or not isinstance(layer.get('sprites'),list):raise ValueError('Invalid fixed layer.')
        for a in layer['sprites']:
            if not isinstance(a,list) or len(a)!=3 or not ints(a[:2],2) or not ints(a[2],4):raise ValueError('Invalid fixed tile.')
            x,y,w,h=a[2]
            if x<0 or y<0 or w!=32 or h!=32 or x+32>1024 or y+32>1152:raise ValueError('Invalid fixed region.')
    # Godot JSON round trips can spell integral coordinates as floating numbers.
    def normalize(v):
        if type(v) is float and math.isfinite(v) and v.is_integer():return int(v)
        if isinstance(v,list):return [normalize(x) for x in v]
        if isinstance(v,dict):return {k:normalize(x) for k,x in v.items()}
        return v
    return normalize(data)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('layout',type=Path);p.add_argument('output',type=Path)
    p.add_argument('--theme');p.add_argument('--road-layer',action='store_true')
    args=p.parse_args();d=json.loads((C/'Metadata/terrain.json').read_text(encoding='utf-8'))
    lay=json.loads(args.layout.read_text(encoding='utf-8-sig'))
    if args.theme:lay['theme']=args.theme
    lay=validate(lay,d);theme=next(t for t in d['themes'] if t['id']==lay['theme'])
    atlas=Image.open(C/theme['atlas']).convert('RGBA')
    if args.road_layer and not connected_material(lay):raise ValueError('Road-layer export requires enabled 1.13/1.14/1.15/1.16 material policy.')
    out=road_layer(lay,atlas,d,theme['id']) if args.road_layer else render(lay,atlas,d,theme['id'])
    args.output.parent.mkdir(parents=True,exist_ok=True);out.save(args.output)
    print(f'Saved {out.width} x {out.height} PNG from delivered production pixels.')

if __name__=='__main__':main()
