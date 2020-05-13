import bpy
import os
#from bpy.props import StringProperty, BoolProperty
#from bpy_extras.io_utils import ImportHelper
#from bpy.types import Operator 
import json
"""
class OT_TestOpenFilebrowser(Operator, ImportHelper): 
    bl_idname = "test.open_filebrowser" 
    bl_label = "Open the file browser (yay)" 
    filter_glob: StringProperty( default='*.json', options={'HIDDEN'} ) 
    #some_boolean: BoolProperty( name='Do a thing', description='Do a thing with the file you\'ve selected', default=True, ) 

    def execute(self, context): 
       
        filename, extension = os.path.splitext(self.filepath) 
        
        with open(self.filepath,"r", encoding = "UTF-8") as f:
            mtlFile = json.load(f)
        
        return {'FINISHED'} 

def register(): 
    bpy.utils.register_class(OT_TestOpenFilebrowser)

def unregister(): 
    bpy.utils.unregister_class(OT_TestOpenFilebrowser) 
    
if __name__ == "__main__": 
    register()

# test call 
bpy.ops.test.open_filebrowser('INVOKE_DEFAULT')
"""

mtlFileName = "E:\\_MTL00.json"
matType = "standard"
diffuseColor = "1,1,1,1"
diffuseMap = "undfined"
reflectionColor = 0.52
reflectionMap = "undefined"
refractionColor = 0.45
refractionMap = "undefined"
metallic = 0
metallicMap = "undefined"
ior = 1.52
iorMap = "undefined"
alpha = 1
alphaMap = "undefined"
normal = "undefined"

#All Materials
allMats = bpy.data.materials[:]

def findImages(list, path):
    index = -1
    
    for n in range(len(list)):
        if list[n].filepath == path:
            index = n
            
    return index

def str2Vector(str):
    vec = eval("[" + str + "]")
    return vec

with open(mtlFileName,'r', encoding = 'utf-8') as f:
    mtlDic = json.load(f)

for i in allMats:
    mtlName = i.name

    nodes = i.node_tree.nodes
    links = i.node_tree.links

    nodes.clear()

    outputShader = nodes.new("ShaderNodeOutputMaterial")

    mapShader = nodes.new("ShaderNodeMapping")
    mapShader.location = (-900, 0)

    texcoordShader = nodes.new("ShaderNodeTexCoord")
    texcoordShader.location = (-1200, 0)

    bsdfShader = nodes.new("ShaderNodeBsdfPrincipled")

    dc = "0.25,0.25,0.25,1"
    #Diffuse Color
    diffuseColor = mtlDic[mtlName][0]["diffuse"]
    
    bsdfShader.inputs[0].default_value = str2Vector(diffuseColor)
    #Reflection Color
    reflectionColor = mtlDic[mtlName][0]["reflection"]

    #Refraction Color
    refractionColor = mtlDic[mtlName][0]["refraction"]

    #Metallic
    metallic = mtlDic[mtlName][0]["metallic"]
    bsdfShader.inputs[5].default_value = metallic

    #IOR
    ior = mtlDic[mtlName][0]["IOR"]
    bsdfShader.inputs[14].default_value = ior

    #Alpha
    alpha = mtlDic[mtlName][0]["alpha"]
    bsdfShader.inputs[18].default_value = alpha

    bsdfShader.location = (-300, 0)
    links.new(bsdfShader.outputs[0],outputShader.inputs[0])

    imgShader = nodes.new("ShaderNodeTexImage")
    imgShader.location = (-600, 0)
    links.new(imgShader.outputs[0], bsdfShader.inputs[0])
    links.new(mapShader.outputs[0], imgShader.inputs[0])
    links.new(texcoordShader.outputs[0], mapShader.inputs[0])
    #Set Image
    diffuseMap = "E:\\maps\\0000\\6.jpg"
    imgs = bpy.data.images
    _index = findImages(imgs,diffuseMap)
    if _index != -1:
        imgShader.image = imgs[_index]
    else:
        imgShader,imge = bpy,data.images.load(diffuseMap)
    
