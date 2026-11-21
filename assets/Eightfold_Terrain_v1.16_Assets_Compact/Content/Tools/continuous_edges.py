import numpy as np
from PIL import Image

def joined(layout,atlas,d,tid,source_layer):
 fieldrect=d['materialFields']['themes'][tid]['region'];field=np.array(atlas.crop((fieldrect[0],fieldrect[1],fieldrect[0]+768,fieldrect[1]+576)))
 prev=np.array(source_layer(layout,atlas,d,tid));alpha=prev[:,:,3].copy();cells={(int(x),int(y)) for x,y,v in layout['roads']}
 # Remove only artificial endpoint notches at shared straight tile boundaries,
 # by copying adjacent existing edge coverage. Preserve real ends and corners.
 for x,y in cells:
  if (x+1,y) in cells:
   for side,dy in [('n',-1),('s',1)]:
    if (x,y+dy) not in cells and (x+1,y+dy) not in cells:
     yy=y*32 if dy==-1 else y*32+28;xx=(x+1)*32
     a=alpha[yy:yy+4,xx-8:xx-7].copy();b=alpha[yy:yy+4,xx+7:xx+8].copy()
     alpha[yy:yy+4,xx-6:xx]=a;alpha[yy:yy+4,xx:xx+6]=b
  if (x,y+1) in cells:
   for dx in [-1,1]:
    if (x+dx,y) not in cells and (x+dx,y+1) not in cells:
     xx=x*32 if dx==-1 else x*32+28;yy=(y+1)*32
     a=alpha[yy-8:yy-7,xx:xx+4].copy();b=alpha[yy+7:yy+8,xx:xx+4].copy()
     alpha[yy-6:yy,xx:xx+4]=a;alpha[yy:yy+6,xx:xx+4]=b
 # Derive a short 2-pixel contact edge from the same world material. No tile rim
 # of another scale is pasted over the field. This is a declared pixel treatment.
 visible=alpha>=192;mask=np.pad(visible,2);h,w=visible.shape
 north=~mask[1:h+1,2:w+2];west=~mask[2:h+2,1:w+1];south=~mask[3:h+3,2:w+2];east=~mask[2:h+2,3:w+3]
 north2=~mask[0:h,2:w+2];west2=~mask[2:h+2,0:w];south2=~mask[4:h+4,2:w+2];east2=~mask[2:h+2,4:w+4]
 rgb=field[:,:,:3].astype(np.int32)
 # Restrained integer adjustments retain source contrast and every inner pixel.
 delta=np.zeros((h,w),np.int32);mask3=np.pad(visible,3);delta[(~mask3[6:h+6,3:w+3])|(~mask3[3:h+3,6:w+6])]=-10;delta[north2|west2]=14;delta[south2|east2]=-24;delta[north|west]=-12;delta[south|east]=-58
 out=field.copy();out[:,:,:3]=np.clip(rgb+delta[:,:,None],0,255).astype(np.uint8);out[:,:,3]=alpha;out[alpha==0]=0
 return Image.fromarray(out)

