"""Validate real skin weights, action channels and the preserved input mesh."""
import hashlib
import io
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]


def read_glb(path):
    data=path.read_bytes()
    magic,version,total=struct.unpack_from('<4sII',data)
    assert magic==b'glTF' and version==2 and total==len(data)
    length,tag=struct.unpack_from('<I4s',data,12)
    assert tag==b'JSON'
    doc=json.loads(data[20:20+length])
    offset=20+length
    binary_length,binary_tag=struct.unpack_from('<I4s',data,offset)
    assert binary_tag==b'BIN\0'
    return doc,memoryview(data)[offset+8:offset+8+binary_length]


def array(doc,binary,index):
    accessor=doc['accessors'][index]
    view=doc['bufferViews'][accessor['bufferView']]
    dtype={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}[accessor['componentType']]
    components={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[accessor['type']]
    itemsize=np.dtype(dtype).itemsize
    offset=view.get('byteOffset',0)+accessor.get('byteOffset',0)
    return np.ndarray((accessor['count'],components),dtype=dtype,buffer=binary,offset=offset,strides=(view.get('byteStride',itemsize*components),itemsize)).copy()


original=ROOT/'source/original_zombie.glb'
assert hashlib.sha256(original.read_bytes()).hexdigest()=='b7d828a23f494b60198b15f1cc472aa560c57bfc335fba88fd94395f14c91a3e'
doc,binary=read_glb(ROOT/'zombie_animated.glb')
old,old_binary=read_glb(original)
assert len(doc['skins'])==1 and len(doc['skins'][0]['joints'])==25
assert len(doc['meshes'])==1 and len(doc['images'])==3
assert all('uri' not in item for item in doc['images']+doc['buffers'])
primitive=doc['meshes'][0]['primitives'][0]
attrs=primitive['attributes']
assert {'POSITION','NORMAL','TEXCOORD_0','TANGENT','JOINTS_0','WEIGHTS_0'}.issubset(attrs)
positions=array(doc,binary,attrs['POSITION'])
old_positions=array(old,old_binary,old['meshes'][0]['primitives'][0]['attributes']['POSITION'])
assert np.all(np.isfinite(positions))
def point_set(points):
    return np.unique(np.rint(points*1000000).astype(np.int64),axis=0)
assert np.array_equal(point_set(positions),point_set(old_positions)), 'Export changed rest mesh geometry'
triangles=len(array(doc,binary,primitive['indices']))//3
assert triangles==382770
weights=array(doc,binary,attrs['WEIGHTS_0'])
joints=array(doc,binary,attrs['JOINTS_0'])
assert weights.shape[1]==4 and np.all(weights>=0)
assert np.max(np.abs(weights.sum(axis=1)-1))<.0001
assert joints.max()<25
durations={}
for animation in doc['animations']:
    assert len(animation['channels'])==75
    times=[]
    for sampler in animation['samplers']:
        t=array(doc,binary,sampler['input'])[:,0]
        values=array(doc,binary,sampler['output'])
        assert np.isfinite(values).all() and np.isfinite(t).all()
        assert t[0]==0 and np.all(np.diff(t)>0)
        times.append(float(t[-1]))
    durations[animation['name']]=round(max(times),3)
assert durations=={'Idle':3.2,'Walk':1.1,'Eat':1.2,'Hit':.4,'Fall':1.8}
for image in doc['images']:
    view=doc['bufferViews'][image['bufferView']]
    start=view.get('byteOffset',0)
    with Image.open(io.BytesIO(bytes(binary[start:start+view['byteLength']]))) as png:
        png.verify()
report={'result':'PASS','joints':25,'maximum_vertex_influences':4,'triangles':triangles,'mesh_rest_geometry_preserved':True,'weight_sum_max_error':float(np.max(np.abs(weights.sum(axis=1)-1))),'animations_seconds':durations,'embedded_images':3,'external_dependencies':0,'original_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),'animated_glb_sha256':hashlib.sha256((ROOT/'zombie_animated.glb').read_bytes()).hexdigest()}
(ROOT/'validation_rig.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
