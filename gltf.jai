//  ------
// | GLTF |
//  ------

// NOTE: only supports .glb files for now
// NOTE: only first mesh for now

GLTF_Model :: struct {
    
    header: GLB_Header;
    
    vertices  : [] Vector3;
    normals   : [] Vector3;
    texcoords : [] Vector2;
    
    is_index_32: bool;
    indices: [] u16;
    #place indices;
    indices_32: [] u32;
    // TODO materials, animations etc. @Incomplete
}

GLB_Header :: struct {
    magic   : u32;
    version : u32;
    length  : u32;
}

GLB_Chunk_Header :: struct {
    length : u32;
    type   : u32;
}

#scope_module

NULL_GLTF :: GLTF_Model.{header=.{magic=0}};

GLTF_Json :: struct {
    meshes      : [] Mesh;
    accessors   : [] Accessor;
    bufferViews : [] Buffer_View;
}

Mesh :: struct {
    primitives: [] Primitive;
}

Primitive :: struct {
    attributes: Attributes;
    indices: u32;
}

Attributes :: struct {
    POSITION   : u32;
    NORMAL     : u32;
    TEXCOORD_0 : u32;
}

Accessor :: struct {
    bufferView    : u32;
    componentType : u32;
    count         : u32;
    type          : string;
}

Buffer_View :: struct {
    buffer     : u32;
    byteLength : u32;
    byteOffset : u32 = 0;
    target     : u32;
}

/*
====================
memcpy_eat (lamdba)
Convenience, memcpy() then advance 'cursor' to end of copy region.
====================
*/
memcpy_eat :: (pdst: *void, psrc: *void, size: s64) #expand {
    memcpy(pdst, psrc, size);
    `cursor += size;
}

#scope_export

/*
====================
gltf_from_data
Create and return a GLTF_Model struct from raw data.
====================
*/
gltf_from_data :: (data: *u8, length: u64) -> GLTF_Model {

    cursor := data;
    gltf_model: GLTF_Model;
    
    memcpy_eat(*gltf_model.header, cursor, size_of(GLB_Header));
    if gltf_model.header.magic != 1179937895 {
	print("[gltf] Bad magic, returning null!\n");
	return NULL_GLTF;
    }

    json_header : GLB_Chunk_Header;
    bin_header  : GLB_Chunk_Header;
    
    // JSON chunk
    memcpy_eat(*json_header, cursor, size_of(GLB_Chunk_Header));
    json := alloc(json_header.length);
    defer free(json);
    memcpy_eat(json, cursor, json_header.length);

    json_str: string;
    json_str.data = json;
    json_str.count = json_header.length;

    success, gltf_json := json_parse_string(json_str, GLTF_Json,, allocator=temp);
    if !success { print("[gltf] JSON parsing failed, returning null!\n"); return NULL_GLTF; }
    
    // BIN chunk
    memcpy_eat(*bin_header, cursor, size_of(GLB_Chunk_Header));
    bin := alloc(bin_header.length);
    defer free(bin);
    memcpy_eat(bin, cursor, bin_header.length);

    // TODO per mesh, concat arrays @Incomplete
    attribs := gltf_json.meshes[0].primitives[0].attributes;
    inds := gltf_json.meshes[0].primitives[0].indices;

    index_acc := gltf_json.accessors[inds];
    // 0x1403: u16 (short)
    // 0x1405: u32
    if index_acc.componentType == 0x1405 gltf_model.is_index_32 = true;
    
    pos_bv := gltf_json.bufferViews[attribs.POSITION];
    normal_bv := gltf_json.bufferViews[attribs.NORMAL];
    texcoord_bv := gltf_json.bufferViews[attribs.TEXCOORD_0];
    index_bv := gltf_json.bufferViews[inds];

    gltf_model.vertices = NewArray(pos_bv.byteLength/size_of(Vector3), Vector3);
    gltf_model.normals = NewArray(normal_bv.byteLength/size_of(Vector3), Vector3);
    gltf_model.texcoords = NewArray(texcoord_bv.byteLength/size_of(Vector2), Vector2);

    memcpy(gltf_model.vertices.data, bin + pos_bv.byteOffset, pos_bv.byteLength);
    memcpy(gltf_model.normals.data, bin + normal_bv.byteOffset, normal_bv.byteLength);
    memcpy(gltf_model.texcoords.data, bin + texcoord_bv.byteOffset, texcoord_bv.byteLength);

    if gltf_model.is_index_32 {
	
	gltf_model.indices_32 = NewArray(index_bv.byteLength/size_of(u32), u32);
	memcpy(gltf_model.indices_32.data, bin + index_bv.byteOffset, index_bv.byteLength);
    }
    else {
	
	gltf_model.indices = NewArray(index_bv.byteLength/size_of(u16), u16);
	memcpy(gltf_model.indices.data, bin + index_bv.byteOffset, index_bv.byteLength);
    }

    return gltf_model;
}

#import "Basic";
#import "File";
#import "Math";
#import,dir "Jaison";
