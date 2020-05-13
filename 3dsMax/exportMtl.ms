try(DestroyDialog exportMtl)catch()

global mtl_name_list = #()
global mtl_list = #()

--Collect All scene material
fn collectMat=
(
	mat = #()
	for x in objects do
	(
		if (findItem mat x.material) == 0 and x.material != undefined do append mat x.material
	)
	return mat
)

fn getAllMat mtl =
(
	--append mtl_list mtl

	mtlType = classof mtl

	case mtlType of
	(
		MultiMaterial:
		(
			for m = 1 to mtl.numsubs do
			(
				getAllMat mtl[m]
			)
		)
		Vray2SideMtl:
		(
			if mtl.fontMtl != undefined do getAllMat mtl.frontMtl
			if mtl.backMtl != undefined do getAllMat mtl.backMtl
		)
		default:
			append mtl_list mtl
	)
)

--查找重复材质，并重新命名
fn simplyMtlName mtl =
(
	_t = mtl.name
	index = findItem mtl_name_list _t
	mtlType = classof mtl

	case mtlType of
	(
		Multimaterial:
		(
			for x = 1 to mtl.numsubs do
			(
				simplyMtlName mtl[x]
			)
		)
		Vray2SideMtl:
		(
			if mtl.backMtl != undefinde do simplyMtlName mtl.frontMtl
			if mtl.backMtl != undefinde do simplyMtlName mtl.backMtl
		)
		default:
		(
			if index != 0 then
			(
				_t += "_dup"
				mtl.name = _t
			)
		)
	)	
	append mtl_name_list _t
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
	newpath = ""

	if doesFileExist path then
	(
		list = FilterString path "\\"
		for i = 1 to list.count do
		(
			
			if i != list.count then
			(
				newpath += list[i] + "\\\\"
			)else(
				newpath += list[i]
			)
		)
	)else(
		newPath = "undefined"
	)
	return newpath
)

--获取材质的可用参数
--返回一个包含16个值的数组
fn getMtlParams mtl =
(
	mtlPars = ""
	mtlType = classof mtl
	/*
	Mtl Pars array
	1.Material Type
	2.Diffuse
	3.Diffuse Texmap
	4.Glossiness
	5.Gloassiness Texmap
	6.Reflection
	7.Reflection Texmap
	8.Refraction
	9.Refraction Texmap
	10.Metallic
	11.Metallic Texmap
	12.IOR
	13.IOR Texmap
	14.Alpha
	15.Alpha Texmap
	16.Normal
	*/
	list = #()
	matType = "PBR"
	diff = "undefined"
	diffmap = "undefined"
	refl = "0"
	reflmap = "undefined"
	glossiness = "0"
	glossinessMap = "undefined"
	refr = "0"
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
			matType = "PBR"
			diff = convertColor2Float mtl.diffuse
			try( diffmap = normalPath mtl.texmap_Diffuse.filename ) catch ()
			refl = (mtl.reflection.value / 255.0) as string
			
			try( reflmap = normalPath mtl.texmap_reflection.filename ) catch ()
			
			refr = (mtl.reflection.value / 255.0) as string
			
			glossiness = mtl.reflection_glossiness
			try( glossinessmap = normalPath mtl.texmap_reflectionGlossiness.filename ) catch ()

			try( refrmap = normalPath mtl.textmap_Refraction.filename ) catch ()		
			
			try(metallic = mtl.reflection_metalness as string)catch(metallic = "0")
			
			try(metallicmap = normalPath mtl.texmap_metalness.filename)catch()
			
			IOR = mtl.refraction_ior as string
			
			try( IORMap = normalPath mtl.texmap_refractionIOR.filename ) catch ()
			
			alpha = "1"
			
			try( alpahMap = normalPath mtl.texmap_opacity.filename ) catch ()
			try( normal = normalPath mtl.texmap_bump.filename ) catch ()
		)
			
		Standardmaterial:
		(
			matType = "PBR"
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
			alpha = (mtl.opacity / 100.0) --as string
			try( alphaMap = normalPath mtl.opacityMap.filename ) catch ()
			try( normal = normalPath mtl.bumpMap.filename ) catch ()
		)
		CoronaMtl:
		(
			matType = "PBR"
			diff = convertColor2Float mtl.colorDiffuse
			try( diffmap = normalPath mtl.texmapDiffuse.filename ) catch ()
			refl = (mtl.colorReflect.value / 255.0) as string
			try( reflmap = normalPath mtl.texmapReflect.filename ) catch ()
			refr = (mtl.colorRefract.value / 255.0) as string
			try( refrmap = normalPath mtl.textmaRefract.filename ) catch ()
			metallic = 0
			metallicMap = "undefined"
			IOR = mtl.ior as string
			try( IORMap = normalPath mtl.texmapIOR.filename ) catch ()
			alpha = "1"
			try( alphaMap = normalPath mtl.texmapOpacity.filename ) catch ()
			try( normal = normalPath mtl.texmapBump.filename ) catch ()
		)
	)
	
	return #(mattype, diff, diffmap, refl, reflmap, glossiness, glossinessmap, refr, refrmap, metallic ,metallicmap, ior ,iormap, alpha, alphamap, normal)
)

--写入文件
fn writeBody mtl file =
(
	pars = getMtlParams mtl

	format "\"%\": [{" mtl.name to:file
	--diffuse color
	format "\"%\":\"%\"," "type" pars[1] to:file
	format "\"%\":\"%\"," "diffuse" pars[2] to:file
	format "\"%\":\"%\"," "diffuseTexmap" pars[3] to:file
	format "\"%\":\"%\"," "reflection" pars[4] to:file
	format "\"%\":\"%\"," "reflectionTexmap" pars[5] to:file
	format "\"%\":\"%\"," "glossiness" pars[6] to:file
	format "\"%\":\"%\"," "glossinessTexmap" pars[7] to:file
	format "\"%\":\"%\"," "refraction" pars[8] to:file
	format "\"%\":\"%\"," "refractionTexmap" pars[9] to:file
	format "\"%\":\"%\"," "metallic" pars[10] to:file
	format "\"%\":\"%\"," "metallicTexmap" pars[11] to:file
	format "\"%\":\"%\"," "IOR" pars[12] to:file
	format "\"%\":\"%\"," "IORTexmap" pars[13] to:file
	format "\"%\":\"%\"," "alpha" pars[14] to:file
	format "\"%\":\"%\"," "alphaTexmap" pars[15] to:file
	format "\"%\":\"%\"" "normal" pars[16] to:file
	format "}]" to:file
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
		Mix:
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
		Vray2SideMtl:
		(
			simplyMat mat.frontMtl
			simplyMat mat.backMtl
		)
		TopBottom:
		(
			simplyMat mat.top
			simplyMat mat.botttom
		)
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
	button btnMtl "导出材质列表" height:45
	label lbl "配合BMax使用"
	
	on btnMtl pressed do
	(		
		--filename = maxFileName
		filename = "BMAX_TMP_MAX.json"
		filePath = "E:\\temp\\Cache\\"
		--filename = replace filename (filename.count-3) 4 "_MTL00.json"
		filename = filePath + filename
		
		if doesFileExist filename then
		(
			try(
				deleteFile filename
			)catch(
				filename = replace filename (filename.count-3) 4 "_MTL00.json"
			)
		)		
		
		ExportMtlFile = createfile filename encoding:#utf8 writeBOM:false 
	
		format "{" to:ExportMtlFile

		allMats = collectMat()

		for i in allMats do
		(	
			--整理场景材质，去除不必要的节点
			simplyMat i
			--场景名字统一化
			simplyMtlName i
		)

		for x in allMats do (
			getAllMat x
		)

		for i = 1 to mtl_list.count do
		(
			writeBody mtl_list[i] ExportMtlFile
			if i != mtl_list.count do format "," to:ExportMtlFile
		)

		format "}" to:ExportMtlFile

		close ExportMtlFile
	)
)

createdialog exportMtl pos:[100,100]
