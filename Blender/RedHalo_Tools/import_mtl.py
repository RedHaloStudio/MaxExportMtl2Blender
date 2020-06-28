import bpy
import os
from bpy.types import Operator 
import json
import tempfile

class Tools_OT_loadMaterials(Operator):
    bl_idname = "redhalo.load_material"
    bl_label = "Load Mateials"
    bl_description = "Load Mateials"
    bl_options = {'REGISTER', 'UNDO'} 

    def execute(self, context): 
        
        def findImages(list, path):
            index = -1
            
            for n in range(len(list)):
                if list[n].filepath == path:
                    index = n       
            return index

        def str2Vector(str):
            vec = eval("[" + str + "]")
            return vec

        def setImages(node, bitmap):
            if (bitmap != "undefined"):
                imgs = bpy.data.images
                _index = findImages(imgs,bitmap)
                if _index != -1:
                    node.image = imgs[_index]
                else:
                    node.image = bpy.data.images.load(bitmap)
                
        def createNodeBitmap(pos, linkNode, bitmap):
            xp = pos[0]
            yp = pos[1]

            imgShader = nodes.new("ShaderNodeTexImage")
            imgShader.location = pos
            
            links.new(imgShader.outputs[0], linkNode)

            setImages(imgShader, bitmap)

            mapShader = nodes.new("ShaderNodeMapping")
            mapShader.location = (xp-600, yp)
            links.new(mapShader.outputs[0], imgShader.inputs[0])

            texcoordShader = nodes.new("ShaderNodeTexCoord")
            texcoordShader.location = (xp-800, yp)
            links.new(texcoordShader.outputs[2], mapShader.inputs[0])

            return imgShader

        def createNodeBrick(pos, *args):
            brickShader = nodes.new("ShaderNodeTexBrick")
            brickShader.location = pos

            brickShader.inputs[1].default_value = str2Vector( args[0][0] )
            brickShader.inputs[3].default_value = str2Vector( args[0][2] )
            
            xp = pos[0]
            yp = pos[1]
            
            if args[0][1] != "undefined": # Color 1
                nPos = (xp-300, yp)
                createNodeBitmap(nPos, brickShader.inputs[1], args[0][1])
                yp -= 300

            if args[0][3] != "undefined": # Mortar
                nPos = (xp-300, yp)
                createNodeBitmap(nPos, brickShader.inputs[3], args[0][3])

            return brickShader

        def createNodeMix(pos, *args):
            mixShader = nodes.new("ShaderNodeMixRGB")
            mixShader.location = pos
            
            mixShader.inputs[0].default_value = float( args[0][4] )
            mixShader.inputs[1].default_value = str2Vector( args[0][0] )
            mixShader.inputs[2].default_value = str2Vector( args[0][2] )
            
            xp = pos[0]
            yp = pos[1]
            
            if args[0][3] != "undefined": # Mask
                nPos = (xp-300, yp)
                createNodeBitmap(nPos, mixShader.inputs[0], args[0][5])
                yp -= 300

            if args[0][1] != "undefined": #Color 1
                nPos = (xp-300, yp)
                createNodeBitmap(nPos, mixShader.inputs[1], args[0][1])
                yp -= 300

            if args[0][3] != "undefined": # Color 2
                nPos = (xp-300, yp)
                createNodeBitmap(nPos, mixShader.inputs[2], args[0][3])

            return mixShader

        def createNodeChecker(pos, *args):
                checkerShader = nodes.new("ShaderNodeTexChecker")
                checkerShader.location = pos
                
                checkerShader.inputs[1].default_value = str2Vector( args[0][0] )
                checkerShader.inputs[2].default_value = str2Vector( args[0][2] )
                checkerShader.inputs[3].default_value = 1
                
                xp = pos[0]
                yp = pos[1]
                
                if args[0][1] != "undefined": # Color 1
                    nPos = (xp-300, yp)
                    createNodeBitmap(nPos, checkerShader.inputs[1], args[0][1])
                    yp -= 300

                if args[0][3] != "undefined": # Mortar
                    nPos = (xp-300, yp)
                    createNodeBitmap(nPos, checkerShader.inputs[2], args[0][2])

                return checkerShader

        # mtlFileName = "E:\\temp\\Cache\\BMAX_TMP_MAX.json"
        # mtlFileName = "D:\\BMAX_TMP_MAX.json"
        mtlFileName = tempfile.gettempdir() + "\\BMAX_TMP_MAX.json"
        #All Materials
        allMats = bpy.data.materials[:]
        with open(mtlFileName,'r', encoding = 'utf-8') as f:
            mtlDic = json.load(f)

        for mat in allMats:
            try:
                mtlName = mat.name
                # mtlName = allMats[1].name
                
                # mat = allMats[1]
                nodes = mat.node_tree.nodes
                links = mat.node_tree.links
                
                xpos = 0
                ypos = 0

                nodes.clear()

                outputShader = nodes.new("ShaderNodeOutputMaterial")
                
                matPars = mtlDic[mtlName][0]
                matType = matPars["MaterialType"]
                
                ypos = 0
                xpos = -300
                
                if matType == "StandardMtl":
                    
                    nodeInputArray = {0:"Diffuse", 4:"Metallic", 5:"Reflection", 7:"Glossiness", 14:"IOR", 15:"Refraction", 16:"RefractionGlossiness", 17:"Emission", 18:"Alpha",19:"Bump"}
                    
                    bsdfShader = nodes.new("ShaderNodeBsdfPrincipled")
                    bsdfShader.location = (xpos, ypos)
                    links.new(bsdfShader.outputs[0], outputShader.inputs[0])

                    for k in nodeInputArray:
                        xpos = -600
                        if k == 0 or k == 17:
                            bsdfShader.inputs[k].default_value = str2Vector(matPars["MaterialProps"][0][nodeInputArray[k]][0]["Color"])
                            
                            if ("TexmapType" in matPars["MaterialProps"][0][nodeInputArray[k]][0]):
                                texmapType = matPars["MaterialProps"][0][nodeInputArray[k]][0]["TexmapType"]
                                texmapProps = matPars["MaterialProps"][0][nodeInputArray[k]][0]["TexmapProps"]
                                
                                pos = (xpos, ypos)
                                # print(texmapProps)

                                if texmapType == "Mix":
                                    newShader = createNodeMix(pos, texmapProps)                         
                                elif texmapType == "Bricker":
                                    newShader = createNodeBrick(pos, texmapProps)
                                elif texmapType == "Checker":
                                    newShader = createNodeChecker(pos, texmapProps)
                                elif texmapType == "Bitmap":
                                    newShader = createNodeBitmap(pos, bsdfShader.inputs[k], texmapProps[0])
                                else:
                                    pass
                                
                                links.new(newShader.outputs[0], bsdfShader.inputs[k])

                                ypos -= 300
                        elif k == 19: # BUMP
                            if ("TexmapType" in matPars["MaterialProps"][0][nodeInputArray[k]][0]):
                                texmapType = matPars["MaterialProps"][0][nodeInputArray[k]][0]["TexmapType"]
                                texmapProps = matPars["MaterialProps"][0][nodeInputArray[k]][0]["TexmapProps"]
                                
                                pos = (xpos, ypos)
                                normalShader = nodes.new("ShaderNodeBump")
                                normalShader.inputs[0].default_value = 0.01
                                normalShader.location = pos
                                
                                pos = (xpos-200, ypos)
                                # print(texmapProps)
                                if texmapType == "Mix":
                                    newShader = createNodeMix(pos, texmapProps)                                          
                                elif texmapType == "Bricker":
                                    newShader = createNodeBrick(pos, texmapProps)
                                elif texmapType == "Checker":
                                    newShader = createNodeChecker(pos, texmapProps)                            
                                elif texmapType == "Bitmap":
                                    newShader = createNodeBitmap(pos, bsdfShader.inputs[k], texmapProps[0])                            
                                else:
                                    pass
                                
                                links.new(normalShader.outputs[0], bsdfShader.inputs[k])                 
                                links.new(newShader.outputs[0], normalShader.inputs[2])

                                ypos -= 300
                        else:
                            bsdfShader.inputs[k].default_value = float(matPars["MaterialProps"][0][nodeInputArray[k]][0]["Color"])
                            
                            if ("TexmapType" in matPars["MaterialProps"][0][nodeInputArray[k]][0]):
                                texmapType = matPars["MaterialProps"][0][nodeInputArray[k]][0]["TexmapType"]
                                texmapProps = matPars["MaterialProps"][0][nodeInputArray[k]][0]["TexmapProps"]
                                
                                pos = (xpos, ypos)
                                
                                if texmapType == "Mix":
                                    newShader = createNodeMix(pos, texmapProps)                            
                                elif texmapType == "Bricker":
                                    newShader = createNodeBrick(pos, texmapProps)
                                elif texmapType == "Checker":
                                    newShader = createNodeChecker(texmapProps)
                                elif texmapType == "Bitmap":
                                    newShader = createNodeBitmap(pos, bsdfShader.inputs[k], texmapProps[0])
                                else:
                                    pass
                                
                                links.new(newShader.outputs[0], bsdfShader.inputs[k])                 

                                ypos -= 300
                elif matType == "LightMtl":
                    emissionShader = nodes.new("ShaderNodeEmission")
                    emissionShader.location = (xpos, ypos)
                    links.new(emissionShader.outputs[0], outputShader.inputs[0])

                    emissionShader.inputs[0].default_value = str2Vector(matPars["MaterialProps"][0]["Color"][0]["Color"])
                    emissionShader.inputs[1].default_value = float(matPars["MaterialProps"][0]["Multiplier"][0]["Multiplier"])
                                       
                    if ("TexmapType" in matPars["MaterialProps"][0]["Color"][0]):                        
                        texmapType = matPars["MaterialProps"][0]["Color"][0]["TexmapType"]                        
                        texmapProps = matPars["MaterialProps"][0]["Color"][0]["TexmapProps"]
                        
                        pos = (xpos-300, ypos)

                        if texmapType == "Mix":
                            newShader = createNodeMix(pos, texmapProps)                      
                        elif texmapType == "Bricker":
                            newShader = createNodeBrick(pos, texmapProps)                             
                        elif texmapType == "Checker":
                            newShader = createNodeChecker(pos, texmapProps)
                        elif texmapType == "Bitmap":
                            newShader = createNodeBitmap(pos, emissionShader.inputs[0], texmapProps[0])
                        else:
                            pass
                    
                        links.new(newShader.outputs[0], emissionShader.inputs[0])                        
                        ypos -= 300

                    if ("TexmapType" in matPars["MaterialProps"][0]["Opacity"][0]):
                        pos = (xpos-300, ypos)
                        texmapType = matPars["MaterialProps"][0]["Opacity"][0]["TexmapType"]
                        texmapProps = matPars["MaterialProps"][0]["Opacity"][0]["TexmapProps"]
                        
                        if texmapType == "Mix":
                            newShader = createNodeMix(pos, texmapProps)                         
                        elif texmapType == "Bricker":
                            newShader = createNodeBrick(pos, texmapProps)
                        elif texmapType == "Checker":
                            newShader = createNodeChecker(pos, texmapProps)
                        elif texmapType == "Bitmap":
                            newShader = createNodeBitmap(pos, emissionShader.inputs[1], texmapProps[0])
                        else:
                            pass
                    
                        links.new(newShader.outputs[0], emissionShader.inputs[1]) 

            except:
                pass

        return {'FINISHED'}