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

mtlFileName = "E:\\temp\\Cache\\BMAX_TMP_MAX.json"
matType = "pbr"
diffuseColor = "1,1,1,1"
diffuseMap = "undfined"
reflectionColor = "0.52"
reflectionMap = "undefined"
glossiness = "0"
refractionColor = "0.45"
refractionMap = "undefined"
metallic = "0"
metallicMap = "undefined"
IOR = "1.52"
IORMap = "undefined"
alpha = "1"
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

for mat in allMats:
    try:
        mtlName = mat.name
        
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links

        ypos = 0

        nodes.clear()

        outputShader = nodes.new("ShaderNodeOutputMaterial")

        mapShader = nodes.new("ShaderNodeMapping")
        mapShader.location = (-1200, 0)

        texcoordShader = nodes.new("ShaderNodeTexCoord")
        texcoordShader.location = (-1500, 0)

        bsdfShader = nodes.new("ShaderNodeBsdfPrincipled")
        bsdfShader.location = (-300, ypos)
        links.new(bsdfShader.outputs[0],outputShader.inputs[0])

        #Diffuse Color
        diffuseColor = mtlDic[mtlName][0]["diffuse"]
        bsdfShader.inputs[0].default_value = str2Vector(diffuseColor)
        #Diffuse Map
        if mtlDic[mtlName][0]["diffuseTexmap"] != "undefined":
            imgShader = nodes.new("ShaderNodeTexImage")
            imgShader.location = (-600, ypos)
            links.new(imgShader.outputs[0], bsdfShader.inputs[0])
            links.new(mapShader.outputs[0], imgShader.inputs[0])
            links.new(texcoordShader.outputs[2], mapShader.inputs[0])
            #Set Image
            diffuseMap = mtlDic[mtlName][0]["diffuseTexmap"]
            imgs = bpy.data.images
            _index = findImages(imgs,diffuseMap)
            if _index != -1:
                imgShader.image = imgs[_index]
            else:
                imgShader.image = bpy.data.images.load(diffuseMap)

        #Reflection Color
        bsdfShader.inputs[5].default_value = float(mtlDic[mtlName][0]["reflection"])
        #Reflection Map
        if mtlDic[mtlName][0]["reflectionTexmap"] != "undefined":
            ypos += -300
            imgShader = nodes.new("ShaderNodeTexImage")
            imgShader.location = (-600, ypos)
            links.new(imgShader.outputs[0], bsdfShader.inputs[6])
            links.new(mapShader.outputs[0], imgShader.inputs[0])
            links.new(texcoordShader.outputs[2], mapShader.inputs[0])
            #Set Image
            reflectionMap = mtlDic[mtlName][0]["reflectionTexmap"]
            imgs = bpy.data.images
            _index = findImages(imgs,reflectionMap)
            if _index != -1:
                imgShader.image = imgs[_index]
            else:
                imgShader.image = bpy.data.images.load(reflectionMap)

        #Glossiness Color
        bsdfShader.inputs[7].default_value = float(mtlDic[mtlName][0]["glossiness"])
        #glossiness Map
        if mtlDic[mtlName][0]["glossinessTexmap"] != "undefined":
            ypos += -300
            imgShader = nodes.new("ShaderNodeTexImage")
            imgShader.location = (-600, ypos)
            links.new(imgShader.outputs[0], bsdfShader.inputs[7])
            links.new(mapShader.outputs[0], imgShader.inputs[0])
            links.new(texcoordShader.outputs[2], mapShader.inputs[0])
            #Set Image
            glossinessMap = mtlDic[mtlName][0]["glossinessTexmap"]
            imgs = bpy.data.images
            _index = findImages(imgs,glossinessMap)
            if _index != -1:
                imgShader.image = imgs[_index]
            else:
                imgShader.image = bpy.data.images.load(glossinessMap)

        #Refraction Color
        bsdfShader.inputs[15].default_value = float(mtlDic[mtlName][0]["refraction"])
        #fefraction Map
        if mtlDic[mtlName][0]["refractionTexmap"] != "undefined":
            ypos += -300
            imgShader = nodes.new("ShaderNodeTexImage")
            imgShader.location = (-600, ypos)
            links.new(imgShader.outputs[0], bsdfShader.inputs[16])
            links.new(mapShader.outputs[0], imgShader.inputs[0])
            links.new(texcoordShader.outputs[2], mapShader.inputs[0])
            #Set Image
            refractionMap = mtlDic[mtlName][0]["refractionTexmap"]
            imgs = bpy.data.images
            _index = findImages(imgs,refractionMap)
            if _index != -1:
                imgShader.image = imgs[_index]
            else:
                imgShader.image = bpy.data.images.load(refractionMap)

        #Metallic
        bsdfShader.inputs[4].default_value = float(mtlDic[mtlName][0]["metallic"])
        #metallic Map
        if mtlDic[mtlName][0]["metallicTexmap"] != "undefined":
            ypos += -300
            imgShader = nodes.new("ShaderNodeTexImage")
            imgShader.location = (-600, ypos)
            links.new(imgShader.outputs[0], bsdfShader.inputs[5])
            links.new(mapShader.outputs[0], imgShader.inputs[0])
            links.new(texcoordShader.outputs[2], mapShader.inputs[0])
            #Set Image
            metallicMap = mtlDic[mtlName][0]["metallicTexmap"]
            imgs = bpy.data.images
            _index = findImages(imgs,metallicMap)
            if _index != -1:
                imgShader.image = imgs[_index]
            else:
                imgShader.image = bpy.data.images.load(metallicMap)

        #IOR
        bsdfShader.inputs[14].default_value = float(mtlDic[mtlName][0]["IOR"])
        #IOR Map
        if mtlDic[mtlName][0]["IORTexmap"] != "undefined":
            ypos += -300
            imgShader = nodes.new("ShaderNodeTexImage")
            imgShader.location = (-600, ypos)
            links.new(imgShader.outputs[0], bsdfShader.inputs[15])
            links.new(mapShader.outputs[0], imgShader.inputs[0])
            links.new(texcoordShader.outputs[2], mapShader.inputs[0])
            #Set Image
            IORMap = mtlDic[mtlName][0]["IORTexmap"]
            imgs = bpy.data.images
            _index = findImages(imgs,IORMap)
            if _index != -1:
                imgShader.image = imgs[_index]
            else:
                imgShader.image = bpy.data.images.load(IORMap)

        #Alpha
        bsdfShader.inputs[18].default_value = float(mtlDic[mtlName][0]["alpha"])        
        #alpha Map
        if mtlDic[mtlName][0]["alphaTexmap"] != "undefined":
            ypos += -300
            imgShader = nodes.new("ShaderNodeTexImage")
            imgShader.location = (-600, ypos)
            links.new(imgShader.outputs[0], bsdfShader.inputs[19])
            links.new(mapShader.outputs[0], imgShader.inputs[0])
            links.new(texcoordShader.outputs[2], mapShader.inputs[0])
            #Set Image
            alphaMap = mtlDic[mtlName][0]["alphaTexmap"]
            imgs = bpy.data.images
            _index = findImages(imgs,alphaMap)
            if _index != -1:
                imgShader.image = imgs[_index]
            else:
                imgShader.image = bpy.data.images.load(alphaMap)

        #normal Map
        if mtlDic[mtlName][0]["normal"] != "undefined":
            ypos += -300
            imgShader = nodes.new("ShaderNodeTexImage")
            imgShader.location = (-900, ypos)

            bumpShader = nodes.new("ShaderNodeBump")
            bumpShader.inputs[0].default_value = 0.1
            bumpShader.location = (-600, ypos)
            
            links.new(bumpShader.outputs[0], bsdfShader.inputs[19])
            links.new(imgShader.outputs[0], bumpShader.inputs[2])
            links.new(mapShader.outputs[0], imgShader.inputs[0])
            links.new(texcoordShader.outputs[2], mapShader.inputs[0])

            #Set Image
            normalMap = mtlDic[mtlName][0]["normal"]
            imgs = bpy.data.images
            _index = findImages(imgs,normalMap)
            if _index != -1:
                imgShader.image = imgs[_index]
            else:
                imgShader.image = bpy.data.images.load(normalMap)

    except:
        print("Something is down")