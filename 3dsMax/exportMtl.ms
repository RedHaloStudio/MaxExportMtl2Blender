try(DestroyDialog exportMtl)catch()

global mtlNameList = #()

--修改重名的文件
fn rename name =
(
	newname = name
	index = findItem mtlNameList newname
	if index != 0 do
	(
		newname = name + "_dup_mtl"
	)
	append mtlNameList newname
	
	return newname
)

fn simplyMtlName mtl =
(
	mtlType = classof mtl
	mtl.name = rename mtl.name
	if mtlType == MultiMaterial do
	(
		for i = 1 to mtl.numsubs do
		(
			simplyMtlName mtl[i]
		)
	)
)

--把RGB转换为浮点型
fn convertColor2Float clr =
(
	ss = StringStream ""
	format "%,%,%,1.00" ((clr.r/255.0) as string) ((clr.g/255.0) as string) ((clr.b/255.0) as string) to:ss
	
	return (ss as string)
)

--格式化路径
fn normalPath path =
(
	list = FilterString path "\\"
	newpath = ""
	for i = 1 to list.count do
	(
		
		if i != list.count then
		(
			newpath += list[i] + "\\\\"
		)else(
			newpath += list[i]
		)
	)
	return newpath
)

--获取材质的可用参数
--返回一个包含13个值的数组
fn getMtlParams mtl =
(
	mtlPars = ""
	mtlType = classof mtl
	/*
	Mtl Pars array
	1.Diffuse
	2.Diffuse Texmap
	3.Reflection
	4.Reflection Texmap
	5.Refraction
	6.Refraction Texmap
	7.Metallic
	8.Metallic Texmap
	9.IOR
	10.IOR Texmap
	11.Alpha
	12.Alpha Texmap
	13.Normal
	*/
	list = #()
	diff = "undefined"
	diffmap = "undefined"
	refl = "undefined"
	reflmap = "undefined"
	refr = "undefined"
	refrmap = "undefined"
	metallic = "0.00"
	metallicmap = "undefined"
	ior = "1.56"
	iormap = "undefined"
	alpha = "undefined"
	alphamap = "undefined"
	normal = "undefined"

	case mtlType of
	(
		VrayMtl:
		(
			diff = convertColor2Float mtl.diffuse
			try( diffmap = normalPath mtl.texmap_Diffuse.filename ) catch ( diffmap = "undefined")
			refl = (mtl.reflection.value / 255.0) as string
			
			try( reflmap = normalPath mtl.texmap_reflection.filename ) catch ( reflmap = "undefined")
			
			refr = (mtl.reflection.value / 255.0) as string
			
			try( refrmap = normalPath mtl.textmap_Refraction.filename ) catch ( refrmap = "undefined" )		
			
			try(metallic = mtl.reflection_metalness as string)catch(metallic = "0")
			
			try(metallicmap = normalPath mtl.texmap_metalness.filename)catch(metallicmap = "undefined")
			
			IOR = mtl.refraction_ior as string
			
			try( IORMap = normalPath mtl.texmap_refractionIOR.filename ) catch ( IORMap = "undefined" )
			
			alpha = "1"
			
			try( alpahMap = normalPath mtl.texmap_opacity.filename ) catch ()
			try( normal = normalPaht mtl.texmap_bump ) catch ()
		)
			
		Standardmaterial:
		(
			diff = convertColor2Float mtl.diffuse
			try( diffmap = normalPath mtl.diffusemap.filename ) catch ()
			refl = "0.5"
			try( reflmap = normalPath mtl.glossinessMap.filename ) catch ()
			refr = "0.5"
			refrmap = "undefined"
			metallic = "0"
			metallicMap = "undefined"
			ior = "1.52"
			IORMap = "undefined"
			alpha = (mtl.opacity / 100.0) as string
			try( alphaMap = normalPath mtl.opacityMap.filename ) catch ()
			try( normal = normalPath mtl.bumpMap.filename ) catch ()
		)
		CoronaMtl:
		(
			diff = convertColor2Float mtl.colorDiffuse
			try( diffmap = normalPath mtl.texmapDiffuse.filename ) catch ()
			refl = (mtl.colorReflect.value / 255.0) as string
			try( reflmap = normalPath mtl.texmapReflect.filename ) catch ()
			refr = (mtl.colorRefract.value / 255.0) as string
			try( refrmap = normalPath mtl.textmaRefract.filename ) catch ()
			metallic = "0"
			metallicMap = "undefined"
			IOR = mtl.ior as string
			try( IORMap = normalPath mtl.texmapIOR.filename ) catch ()
			alpha = "1"
			try( alphaMap = normalPath mtl.texmapOpacity.filename ) catch ()
			try( normal = normalPath mtl.texmapBump.filename ) catch ()
		)
	)
	
	return #(diff, diffmap, refl, reflmap, refr, refrmap, metallic ,metallicmap, ior ,iormap, alpha, alphamap, normal)
)

--写入文件
fn writeBody mtl file =
(
	pars = getMtlParams mtl

	format "\"%\": [{" mtl.name to:file
	--diffuse color
	format "\"%\":\"%\"," "diffuse" pars[1] to:file
	format "\"%\":\"%\"," "diffuseTexmap" pars[2] to:file
	format "\"%\":\"%\"," "reflection" pars[3] to:file
	format "\"%\":\"%\"," "reflectionTexmap" pars[4] to:file
	format "\"%\":\"%\"," "refraction" pars[5] to:file
	format "\"%\":\"%\"," "refractionTexmap" pars[6] to:file
	format "\"%\":\"%\"," "metallic" pars[7] to:file
	format "\"%\":\"%\"," "metallicTexmap" pars[8] to:file
	format "\"%\":\"%\"," "IOR" pars[9] to:file
	format "\"%\":\"%\"," "IORTexmap" pars[10] to:file
	format "\"%\":\"%\"," "alpha" pars[11] to:file
	format "\"%\":\"%\"," "alphaTexmap" pars[12] to:file
	format "\"%\":\"%\"" "normal" pars[13] to:file
	format "}], \n" to:file
)

--整理场景中的纹理
fn simplyTex node =
(
	try( nodeType = classof node ) catch ()

	case nodeType of
	(
		Color_Correction:
			return (simplyTex node.map)
		CompositeTexturemap:
			return (simplyTex node.maplist[1])
		FallOff:
			return (simplyTex node.map1)
		Output:
			return (simplyTex node.map1)
		RGB_Multiply:
			return (simplyTex node.map1)
		VrayDirt:
			return (simplyTex node.texmap_unoccluded_color)
		VRayNormalMap:
			return (simplyTex node.normal_map)
		VRayColor2Bump:
			return (simplyTex node.map)
		VRayTriplanarTex:
			return (simplyTex node.texture)
		CoronaColorCorrect:
			return (simplyTex node.inputTexmap)
		CoronaAO:
			return (simplyTex node.colorUnoccluded)
		CoronaNormal:
			return (simplyTex node.normalMap)
		default:
			return node
	)	
)

--整理所有材质
fn simplyMat mat =
(
	--整理场景材质
	matType = classof mat
	case matType of
	(
		VrayMtl:
			mat.texmap_diffuse = simplyTex mat.texmap_diffuse
		Standardmaterial:
			mat.diffuseMap = simplyTex mat.diffuseMap
		CoronaMtl:
		(
			mat.texmapDiffuse = simplyTex mat.texmapDiffuse
			mat.texmapReflect = simplyTex mat.texmapReflect
			mat.texmapReflectGlossiness = simplyTex mat.texmapReflectGlossiness
			mat.texmapRefract = simplyTex mat.texmapRefract
			mat.texmapRefractGlossiness = simplyTex mat.texmapRefractGlossiness
			mat.texmapBump = simplyTex mat.texmapBump
			mat.texmapOpacity = simplyTex mat.texmapOpacity
		)
		VRayLightMtl:
			mat.texmap = simplyTex mat.texmap
		CoronaLightMtl:
		(
			mat.texmap = simplyTex mat.texmap
			mat.opacityTexmap = simplyTex mat.opacityTexmap
		)
		TopBottom:
			simplyMat mat.top
		VRayBlendMtl:
			simplyMat mat.baseMtl
		VRayOverrideMtl:
			simplyMat mat.baseMtl
		MultiMaterial:
		(
			for i = 1 to mat.numsubs do
			(
				simplyMat mat[i]
			)
		)
	)
)

---UI界面
rollout exportMtl "Export Mtl"
(	
	button btnDebug "1.整理场景材质"
	
	on btnDebug pressed do
	(
		--holdMaxFile() 
		mtlNameList = #()

		for i in sceneMaterials do
		(	
			--整理场景材质，去除不必要的节点
			simplyMat i
			--场景名字统一化
			simplyMtlName i
		)

		free mtlNameList
	)
	
	button btnMtl "2.导出材质列表"
	
	on btnMtl pressed do
	(		
		filename = maxFileName
		-->replace <string> <from_integer> <length_integer> <new_string>
		filename = replace filename (filename.count-3) 4 "_MTL.json"
		filename = maxFilePath + filename
		
		if doesFileExist filename then
		(
			try(
				deleteFile filename
			)catch(
				filename = replace filename (filename.count-3) 4 "_MTL.json"
			)
		)
		print filename
		ExportMtlFile = createfile filename
		
		
		format "{" to:ExportMtlFile
		
		for i in sceneMaterials do
		(
			writeBody i ExportMtlFile
			if classof i == MultiMaterial do
			(
				for j = 1 to i.numsubs do
				(
					writeBody i[j] ExportMtlFile
				)
			)
		)
		
		format "}" to:ExportMtlFile
		
		--print ExportMtlFile
		close ExportMtlFile 	
	)
)

createdialog exportMtl pos:[100,100]
