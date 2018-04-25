tool
extends EditorPlugin

var import_plugin
var control

func _enter_tree():
	#Add import plugin
	import_plugin = ImportPlugin.new()
	add_import_plugin(import_plugin)

func _exit_tree():
	#remove plugin
	remove_import_plugin(import_plugin)
	import_plugin = null

##############################################
#                Import Plugin               #
##############################################
class MagicaVoxelData:
	var pos = Vector3(0,0,0)
	var color
	func init(file):
		pos.x = file.get_8()
		pos.z = -file.get_8()
		pos.y = file.get_8()
		
		color = file.get_8()

class ImportPlugin extends EditorImportPlugin:
	#The Name shown in the Plugin Menu
	func get_importer_name():
		return 'MagicaVoxel-Importer'
	
	#The Name shown under 'Import As' in the Import menu
	func get_visible_name():
		return "MagicaVoxels as Mesh"
	
	#The File extensions that this Plugin can import. Those will then show up in the Filesystem
	func get_recognized_extensions():
		return ['vox']
	
	#The Resource Type it creates. Im still not sure what exactly this does
	func get_resource_type():
		return "Mesh"
	
	#The extenison the imported file will have
	func get_save_extension():
		return 'mesh'
	
	#Returns an Array or Dictionaries that declare which options exist.
	#Those options will show up under 'Import As'
	func get_import_options(preset):
		var options = []
		#options.append( { "name":"Pack in scene", "default_value":false } )
		#options.append( { "name":"target_path", "default_value":"" } )
		return options
	
	#The Number of presets
	func get_preset_count():
		return 0
	
	#The Name of the preset.
	func get_preset_name(preset):
		return "Default"
	
	#Gets called when pressing a file gets imported / reimported
	func import( source_path, save_path, options, platforms, gen_files ):
		#Initialize and populate voxel array
		var voxelArray = []
		for x in range(0,128):
			voxelArray.append([])
			for y in range(0,128):
				voxelArray[x].append([])
				voxelArray[x][y].resize(128)
		
		var file = File.new()
		var error = file.open( source_path, File.READ )
		if error != OK:
			if file.is_open(): file.close()
			return error
		
		##################
		#  Import Voxels #
		##################
		var colors = null
		var data = null
		#var derp = PoolByteArray(file.get_8()).get
		var magic = PoolByteArray([file.get_8(),file.get_8(),file.get_8(),file.get_8()]).get_string_from_ascii()
		
		var version = file.get_32()
		 
		# a MagicaVoxel .vox file starts with a 'magic' 4 character 'VOX ' identifier
		if magic == "VOX ":
			var sizex = 0
			var sizey = 0
			var sizez = 0
			
			while file.get_position() < file.get_len():
				# each chunk has an ID, size and child chunks
				var chunkId = PoolByteArray([file.get_8(),file.get_8(),file.get_8(),file.get_8()]).get_string_from_ascii() #char[] chunkId
				var chunkSize = file.get_32()
				var childChunks = file.get_32()
				var chunkName = chunkId
				# there are only 2 chunks we only care about, and they are SIZE and XYZI
				if chunkName == "SIZE":
					sizex = file.get_32()
					sizey = file.get_32()
					sizez = file.get_32()
					 
					file.get_buffer(chunkSize - 4 * 3)
				elif chunkName == "XYZI":
					# XYZI contains n voxels
					var numVoxels = file.get_32()
					
					# each voxel has x, y, z and color index values
					data = []
					for i in range(0,numVoxels):
						var mvc = MagicaVoxelData.new()
						mvc.init(file)
						data.append(mvc)
						voxelArray[mvc.pos.x][mvc.pos.y][mvc.pos.z] = mvc
				elif chunkName == "RGBA":
					colors = []
					 
					for i in range(0,256):
						var r = float(file.get_8() / 255.0)
						var g = float(file.get_8() / 255.0)
						var b = float(file.get_8() / 255.0)
						var a = float(file.get_8() / 255.0)
						
						colors.append(Color(r,g,b,a))
						
				else: file.get_buffer(chunkSize)  # read any excess bytes
			
			if data.size() == 0: return data #failed to read any valid voxel data
			 
			# now push the voxel data into our voxel chunk structure
			for i in range(0,data.size()):
				# use the voxColors array by default, or overrideColor if it is available
				if colors == null:
					data[i].color = to_rgb(voxColors[data[i].color]-1)
				else:
					data[i].color = colors[data[i].color-1]
		file.close()
		
		##################
		#   Create Mesh  #
		##################
		
		#Calculate offset
		var s_x = 1000
		var m_x = -1000
		var s_z = 1000
		var m_z = -1000
		for voxel in data:
			if voxel.pos.x < s_x: s_x = voxel.pos.x
			elif voxel.pos.x > m_x: m_x = voxel.pos.x
			if voxel.pos.z < s_z: s_z = voxel.pos.z
			elif voxel.pos.z > m_z: m_z = voxel.pos.z
		var x_dif = m_x - s_x
		var z_dif = m_z - s_z
		var dif = Vector3(-s_x-x_dif/2.0,0,-s_z-z_dif/2.0)
		
		#Create the mesh
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for voxel in data:
			var to_draw = []
			if not above(voxel,voxelArray): to_draw += top
			if not below(voxel,voxelArray): to_draw += down
			if not onleft(voxel,voxelArray): to_draw += left
			if not onright(voxel,voxelArray): to_draw += right
			if not infront(voxel,voxelArray): to_draw += front
			if not behind(voxel,voxelArray): to_draw += back
			
			st.add_color(voxel.color)
			for tri in to_draw:
				st.add_vertex( (tri*0.5)+voxel.pos+dif)
		st.generate_normals()
		
		var material = SpatialMaterial.new()
		material.vertex_color_is_srgb = true
		material.vertex_color_use_as_albedo = true
		material.roughness = 1
		#material.set_flag(material.FLAG_USE_COLOR_ARRAY,true)
		st.set_material(material)
		var mesh
		
		if file.file_exists(save_path) and false:
			var old_mesh = ResourceLoader.load(save_path)
			old_mesh.surface_remove(0)
			mesh = st.commit(old_mesh)
		else:
			mesh = st.commit()
		
		var full_path = "%s.%s" % [save_path, get_save_extension()]
		return ResourceSaver.save( full_path, mesh )
	
	#Data
	var voxColors = [
		0x00000000, 0xffffffff, 0xffccffff, 0xff99ffff, 0xff66ffff, 0xff33ffff, 0xff00ffff, 0xffffccff, 0xffccccff, 0xff99ccff, 0xff66ccff, 0xff33ccff, 0xff00ccff, 0xffff99ff, 0xffcc99ff, 0xff9999ff,
		0xff6699ff, 0xff3399ff, 0xff0099ff, 0xffff66ff, 0xffcc66ff, 0xff9966ff, 0xff6666ff, 0xff3366ff, 0xff0066ff, 0xffff33ff, 0xffcc33ff, 0xff9933ff, 0xff6633ff, 0xff3333ff, 0xff0033ff, 0xffff00ff,
		0xffcc00ff, 0xff9900ff, 0xff6600ff, 0xff3300ff, 0xff0000ff, 0xffffffcc, 0xffccffcc, 0xff99ffcc, 0xff66ffcc, 0xff33ffcc, 0xff00ffcc, 0xffffcccc, 0xffcccccc, 0xff99cccc, 0xff66cccc, 0xff33cccc,
		0xff00cccc, 0xffff99cc, 0xffcc99cc, 0xff9999cc, 0xff6699cc, 0xff3399cc, 0xff0099cc, 0xffff66cc, 0xffcc66cc, 0xff9966cc, 0xff6666cc, 0xff3366cc, 0xff0066cc, 0xffff33cc, 0xffcc33cc, 0xff9933cc,
		0xff6633cc, 0xff3333cc, 0xff0033cc, 0xffff00cc, 0xffcc00cc, 0xff9900cc, 0xff6600cc, 0xff3300cc, 0xff0000cc, 0xffffff99, 0xffccff99, 0xff99ff99, 0xff66ff99, 0xff33ff99, 0xff00ff99, 0xffffcc99,
		0xffcccc99, 0xff99cc99, 0xff66cc99, 0xff33cc99, 0xff00cc99, 0xffff9999, 0xffcc9999, 0xff999999, 0xff669999, 0xff339999, 0xff009999, 0xffff6699, 0xffcc6699, 0xff996699, 0xff666699, 0xff336699,
		0xff006699, 0xffff3399, 0xffcc3399, 0xff993399, 0xff663399, 0xff333399, 0xff003399, 0xffff0099, 0xffcc0099, 0xff990099, 0xff660099, 0xff330099, 0xff000099, 0xffffff66, 0xffccff66, 0xff99ff66,
		0xff66ff66, 0xff33ff66, 0xff00ff66, 0xffffcc66, 0xffcccc66, 0xff99cc66, 0xff66cc66, 0xff33cc66, 0xff00cc66, 0xffff9966, 0xffcc9966, 0xff999966, 0xff669966, 0xff339966, 0xff009966, 0xffff6666,
		0xffcc6666, 0xff996666, 0xff666666, 0xff336666, 0xff006666, 0xffff3366, 0xffcc3366, 0xff993366, 0xff663366, 0xff333366, 0xff003366, 0xffff0066, 0xffcc0066, 0xff990066, 0xff660066, 0xff330066,
		0xff000066, 0xffffff33, 0xffccff33, 0xff99ff33, 0xff66ff33, 0xff33ff33, 0xff00ff33, 0xffffcc33, 0xffcccc33, 0xff99cc33, 0xff66cc33, 0xff33cc33, 0xff00cc33, 0xffff9933, 0xffcc9933, 0xff999933,
		0xff669933, 0xff339933, 0xff009933, 0xffff6633, 0xffcc6633, 0xff996633, 0xff666633, 0xff336633, 0xff006633, 0xffff3333, 0xffcc3333, 0xff993333, 0xff663333, 0xff333333, 0xff003333, 0xffff0033,
		0xffcc0033, 0xff990033, 0xff660033, 0xff330033, 0xff000033, 0xffffff00, 0xffccff00, 0xff99ff00, 0xff66ff00, 0xff33ff00, 0xff00ff00, 0xffffcc00, 0xffcccc00, 0xff99cc00, 0xff66cc00, 0xff33cc00,
		0xff00cc00, 0xffff9900, 0xffcc9900, 0xff999900, 0xff669900, 0xff339900, 0xff009900, 0xffff6600, 0xffcc6600, 0xff996600, 0xff666600, 0xff336600, 0xff006600, 0xffff3300, 0xffcc3300, 0xff993300,
		0xff663300, 0xff333300, 0xff003300, 0xffff0000, 0xffcc0000, 0xff990000, 0xff660000, 0xff330000, 0xff0000ee, 0xff0000dd, 0xff0000bb, 0xff0000aa, 0xff000088, 0xff000077, 0xff000055, 0xff000044,
		0xff000022, 0xff000011, 0xff00ee00, 0xff00dd00, 0xff00bb00, 0xff00aa00, 0xff008800, 0xff007700, 0xff005500, 0xff004400, 0xff002200, 0xff001100, 0xffee0000, 0xffdd0000, 0xffbb0000, 0xffaa0000,
		0xff880000, 0xff770000, 0xff550000, 0xff440000, 0xff220000, 0xff110000, 0xffeeeeee, 0xffdddddd, 0xffbbbbbb, 0xffaaaaaa, 0xff888888, 0xff777777, 0xff555555, 0xff444444, 0xff222222, 0xff111111
		]
	
	var top = [
		Vector3( 1.0000, 1.0000, 1.0000),
		Vector3(-1.0000, 1.0000, 1.0000),
		Vector3(-1.0000, 1.0000,-1.0000),
		
		Vector3(-1.0000, 1.0000,-1.0000),
		Vector3( 1.0000, 1.0000,-1.0000),
		Vector3( 1.0000, 1.0000, 1.0000),
	]
	
	var down = [
		Vector3(-1.0000,-1.0000,-1.0000),
		Vector3(-1.0000,-1.0000, 1.0000),
		Vector3( 1.0000,-1.0000, 1.0000),
		
		Vector3( 1.0000, -1.0000, 1.0000),
		Vector3( 1.0000, -1.0000,-1.0000),
		Vector3(-1.0000, -1.0000,-1.0000),
	]
	
	var front = [
		Vector3(-1.0000, 1.0000, 1.0000),
		Vector3( 1.0000, 1.0000, 1.0000),
		Vector3( 1.0000,-1.0000, 1.0000),
		
		Vector3( 1.0000,-1.0000, 1.0000),
		Vector3(-1.0000,-1.0000, 1.0000),
		Vector3(-1.0000, 1.0000, 1.0000),
	]
	
	var back = [
		Vector3( 1.0000,-1.0000,-1.0000),
		Vector3( 1.0000, 1.0000,-1.0000),
		Vector3(-1.0000, 1.0000,-1.0000),
		
		Vector3(-1.0000, 1.0000,-1.0000),
		Vector3(-1.0000,-1.0000,-1.0000),
		Vector3( 1.0000,-1.0000,-1.0000)
	]
	
	var left = [
		Vector3(-1.0000, 1.0000, 1.0000),
		Vector3(-1.0000,-1.0000, 1.0000),
		Vector3(-1.0000,-1.0000,-1.0000),
		
		Vector3(-1.0000,-1.0000,-1.0000),
		Vector3(-1.0000, 1.0000,-1.0000),
		Vector3(-1.0000, 1.0000, 1.0000),
	]
	
	var right = [
		Vector3( 1.0000, 1.0000, 1.0000),
		Vector3( 1.0000, 1.0000,-1.0000),
		Vector3( 1.0000,-1.0000,-1.0000),
		
		Vector3( 1.0000,-1.0000,-1.0000),
		Vector3( 1.0000,-1.0000, 1.0000),
		Vector3( 1.0000, 1.0000, 1.0000),
	]
	
	#Some staic functions
	func above(cube,array): return array[cube.pos.x][cube.pos.y+1][cube.pos.z]
	func below(cube,array): return array[cube.pos.x][cube.pos.y-1][cube.pos.z]
	func onleft(cube,array): return array[cube.pos.x-1][cube.pos.y][cube.pos.z]
	func onright(cube,array): return array[cube.pos.x+1][cube.pos.y][cube.pos.z]
	func infront(cube,array): return array[cube.pos.x][cube.pos.y][cube.pos.z+1]
	func behind(cube,array): return array[cube.pos.x][cube.pos.y][cube.pos.z-1]