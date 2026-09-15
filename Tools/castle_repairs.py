"""Explicit repairs for the supplied castle export; all coordinates are metres.
Uses the author's existing images. No generic white fallback is shipped.
"""
import numpy as np
import trimesh

FLOOR=4.72
A=np.radians(25)
WEST=np.array([[np.cos(A),0,np.sin(A)],[0,1,0],[-np.sin(A),0,np.cos(A)]])
IDENTITY=np.eye(3)
# Door boxes in each room's coordinate frame. Clip actual visual faces, never
# just collision. The west study follows the original 25-degree wall orientation.
PORTALS=[('East workshop',IDENTITY,[7.1,4.2,1.2],[8.6,7.18,3.4]),
         ('North timber hall',IDENTITY,[1.2,4.2,7.7],[3.8,7.18,9.35]),
         ('West study',WEST,[-8.3,4.2,1.45],[-6.1,7.12,2.5])]
ROOMS=[dict(name='East workshop',basis=IDENTITY,x=(8.25,15.05),z=(-.2,4.35),top=7.7,door=(1.2,3.4),side='x'),
       dict(name='North timber hall',basis=IDENTITY,x=(-.3,11.65),z=(9.05,14.6),top=7.4,door=(1.2,3.8),side='open'),
       dict(name='West study',basis=WEST,x=(-9.8,-4.75),z=(2.15,5.6),top=7.08,door=(-8.3,-6.1),side='z')]

# Clear source floor slabs/internal caps from the new playable room volumes.
# Exterior walls/roofs remain outside these volumes; liners close the inside.
for room in ROOMS:
    PORTALS.append((room['name']+' interior',room['basis'],
                    [room['x'][0],FLOOR+.001,room['z'][0]],
                    [room['x'][1],room['top'],room['z'][1]]))

def replacement(name, mi):
    if mi is None:
        if name in ['Plane.062','Plane.030','Plane.026']:return 3
        if name=='Circle.083':return 4
        if name.startswith('Cube.'):return 40  # author's ocean-rock set
        if name.startswith('Circle.'):return 2
        if name.startswith('Vert'):return 63  # courtyard stepping stones
        return 0  # window surrounds, masonry trim and small facade blocks
    return {50:0,64:0,73:71,74:3,78:63}.get(mi,mi)

def clip(poly, axis, value, keep_greater):
    out=[]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        ia=a[axis]>=value if keep_greater else a[axis]<=value
        ib=b[axis]>=value if keep_greater else b[axis]<=value
        if ia:out.append(a)
        if ia != ib:out.append(a+(b-a)*((value-a[axis])/(b[axis]-a[axis])))
    return out

def cut_portals(points,normals,uv,indices):
    data=np.concatenate([points,normals,uv if uv is not None else np.zeros((len(points),2))],axis=1)
    triangles=data[indices];edits=[]
    for name,basis,lo,hi in PORTALS:
        q=triangles[:,:,:3]@basis
        intersects=np.all(q.max(1)>lo,axis=1)&np.all(q.min(1)<hi,axis=1)
        if not intersects.any():continue
        result=list(triangles[~intersects]);removed=0
        for tri in triangles[intersects]:
            transformed=tri.copy();transformed[:,:3]=tri[:,:3]@basis
            current=list(transformed);pieces=[]
            for axis in range(3):
                if not current:break
                pieces.append(clip(current,axis,lo[axis],False))
                current=clip(current,axis,lo[axis],True)
                if not current:break
                pieces.append(clip(current,axis,hi[axis],True))
                current=clip(current,axis,hi[axis],False)
            if len(current)>=3:removed+=1
            for poly in pieces:
                for j in range(1,len(poly)-1):
                    t=np.array([poly[0],poly[j],poly[j+1]]);t[:,:3]=t[:,:3]@basis.T
                    if np.linalg.norm(np.cross(t[1,:3]-t[0,:3],t[2,:3]-t[0,:3]))>1e-8:result.append(t)
        triangles=np.array(result).reshape(-1,3,8)
        if removed:edits.append({'room':name,'intersected_source_triangles':removed})
    flat=triangles.reshape(-1,8)
    return flat[:,:3],flat[:,3:6],flat[:,6:],np.arange(len(flat)).reshape(-1,3),edits

def fix_winding(points,normals,indices):
    # Several exported rocks and wall components have negative signed volume.
    # Repair each connected shell, preserving triangle order and original UVs.
    mesh=trimesh.Trimesh(points.copy(),indices.copy(),process=False)
    mesh.merge_vertices();mesh.fix_normals(multibody=True)
    old=np.cross(points[indices[:,1]]-points[indices[:,0]],points[indices[:,2]]-points[indices[:,0]])
    new=mesh.face_normals
    flip=(old*new).sum(1)<0
    indices=indices.copy();indices[flip]=indices[flip][:,[0,2,1]]
    # Vertex splitting at repair seams keeps the original authored smooth normals.
    n=normals[indices].copy();n[flip]*=-1
    return points[indices].reshape(-1,3),n.reshape(-1,3),indices, int(flip.sum())

def projected_uv(points,indices,tile):
    tri=points[indices];n=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]);axis=np.abs(n).argmax(1)
    uv=np.zeros((len(tri),3,2))
    for a,components in [(0,[2,1]),(1,[0,2]),(2,[0,1])]:
        uv[axis==a]=tri[axis==a][:,:,components]/tile
    uv[:,:,1]=1-uv[:,:,1]
    return uv.reshape(-1,2)

def tile_size(mi):
    if mi in [0,1,55,57,58,59,60,67]:return 2.5
    if mi in [3,45,51,66]:return 1.5
    if mi in [4,5,7,62,65,68,69]:return 2.0
    if mi in [63,76,77,79,80]:return 1.8
    return 3.0

def interior_parts():
    parts=[]
    def box(name,lo,hi,basis,mi):
        mesh=trimesh.creation.box(extents=np.array(hi)-lo)
        mesh.apply_translation((np.array(hi)+lo)/2)
        p=mesh.vertices@basis.T;n=mesh.vertex_normals@basis.T
        parts.append((name,p,n,None,mesh.faces,mi))
    for name,basis,lo,hi in PORTALS[:3]:
        box(name+' threshold',[lo[0],FLOOR-.12,lo[2]],[hi[0],FLOOR,hi[2]],basis,2)
    for room in ROOMS:
        name=room['name'];basis=room['basis'];x0,x1=room['x'];z0,z1=room['z'];top=room['top'];a,b=room['door']
        box(name+' floor',[x0,FLOOR-.12,z0],[x1,FLOOR,z1],basis,3 if room['side']=='open' else 2)
        if room['side']!='open':
            box(name+' ceiling',[x0,top,z0],[x1,top+.10,z1],basis,3)
            if room['side']=='x':
                box(name+' front A',[x0-.10,FLOOR,z0],[x0,top,a],basis,0)
                box(name+' front B',[x0-.10,FLOOR,b],[x0,top,z1],basis,0)
                box(name+' back',[x1,FLOOR,z0],[x1+.1,top,z1],basis,0)
                box(name+' side A',[x0,FLOOR,z0-.1],[x1,top,z0],basis,0)
                box(name+' side B',[x0,FLOOR,z1],[x1,top,z1+.1],basis,0)
                box(name+' lintel',[x0-.1,7.18,a],[x0,top,b],basis,0)
            else:
                box(name+' front A',[x0,FLOOR,z0-.1],[a,top,z0],basis,0)
                box(name+' front B',[b,FLOOR,z0-.1],[x1,top,z0],basis,0)
                box(name+' back',[x0,FLOOR,z1],[x1,top,z1+.1],basis,0)
                box(name+' side A',[x0-.1,FLOOR,z0],[x0,top,z1],basis,0)
                box(name+' side B',[x1,FLOOR,z0],[x1+.1,top,z1],basis,0)
            # Furniture sits by the back wall, clear of the entry route.
        tx=x1-1.1;tz=z1-1.0
        box(name+' workbench',[tx-.7,FLOOR+.76,tz-.4],[tx+.7,FLOOR+.9,tz+.4],basis,3)
        for dx in [-.55,.55]:
            for dz in [-.28,.28]:box(name+' bench leg',[tx+dx-.06,FLOOR,tz+dz-.06],[tx+dx+.06,FLOOR+.76,tz+dz+.06],basis,3)
    return parts
