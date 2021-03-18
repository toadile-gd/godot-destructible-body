tool
extends RigidBody


class_name DestructibleBody, "icon.png"


# user-configurable variables
export (Mesh) var base_mesh setget _assign_geometry # yo
export (Material) var base_material setget _assign_material
export (Material) var underlying_material
export (Mesh) var chunk_mesh
export var chunk_damping : float = 0.0
export var chunk_explosiveness : float = 5.0
export var chunk_scale_adjustmenst : float = 1.0
export var chunk_density : float = 1.0
export var chunk_lifetime : float = -1.0
export(int, LAYERS_3D_PHYSICS) var chunk_physics_layer = 1
export(int, LAYERS_3D_PHYSICS) var chunk_physics_mask = 1
export (ParticlesMaterial) var debris_particles
export (Mesh) var debris_draw_instance
export var use_inertia : bool = false
export var inertia_tolerance : float = 100.0
export var rb_contacts_reported : int = 5
export var particles_lifetime : float = 1.0
export var max_destruction_pieces = 5
export var set_rigid_on_max_destruction : bool = false


# internal variables
var destruction_pieces = 0
var local_collision_pos : Vector3
var collision_normal : Vector3
var csg_base : CSGMesh
var collision_shape : CollisionShape
var mesh_for_dimensions : MeshInstance
var can_destroy : bool = true
const chunk_shrink_factor = 0.85

signal on_destruct(collision_point)


# Handles this object as it enters the main tree.
func _enter_tree():
	if !is_instance_valid(chunk_mesh):
		chunk_mesh = SphereMesh.new()
		chunk_mesh.rings = 2
		chunk_mesh.radial_segments = 5
	if not Engine.editor_hint:
		if not is_instance_valid(underlying_material):
			underlying_material = base_material
		mesh_for_dimensions = MeshInstance.new()
		mesh_for_dimensions.mesh = chunk_mesh


# Initializes this object's scale and other aspects in game.
func _ready():
	if not Engine.editor_hint:
		connect("body_entered", self, "_on_collision")
		# apply scale to children and revert primary scale
		if not is_instance_valid(base_mesh):
			_assign_geometry(CubeMesh.new())
		csg_base.scale *= scale
		collision_shape.scale *= scale
		scale = scale / scale
		contacts_reported = rb_contacts_reported
		contact_monitor = true
		linear_damp = chunk_damping
		angular_damp = chunk_damping


# Assigns the geometry to this object in the editor and game view.
func _assign_geometry(new_mesh):
	if base_mesh != new_mesh:
		base_mesh = new_mesh
		if is_instance_valid(base_mesh):
			if (is_instance_valid(csg_base)):
				csg_base.queue_free()
			csg_base = CSGMesh.new()
			add_child(csg_base)
			csg_base.mesh = base_mesh
			csg_base.material = base_material
			csg_base.operation = CSGShape.OPERATION_UNION
			collision_shape.shape = base_mesh.create_trimesh_shape()
		else:
			csg_base.queue_free()
	elif new_mesh == null:
		base_mesh.queue_free()
		csg_base.queue_free()


# Assigns the material to this object in the editor and game view.
func _assign_material(material):
	if base_material != material:
		base_material = material
		if is_instance_valid(base_mesh):
			csg_base.material = base_material


# Initializes this object.
func _init():
	collision_shape = CollisionShape.new()
	collision_shape.name = "col"
	add_child(collision_shape)
	mode = RigidBody.MODE_STATIC
	can_sleep = false
	contact_monitor = true
	contacts_reported = 4


# Finds the latest collision point which should be useful enough for
# a destruction point.
# credit to u/Mars-Is-A-Tank
func _integrate_forces( state ):
	if(use_inertia && state.get_contact_count() >= 1 && can_destroy):  # this check is needed or it will throw errors 
		local_collision_pos = state.get_contact_collider_position(state.get_contact_count()-1)
		collision_normal = state.get_contact_local_normal(state.get_contact_count()-1)


# Handles collisions and inertia-based destruction.
func _on_collision(body):
	var collision_position : Vector3 = local_collision_pos
	if (body is RigidBody && use_inertia):
		var inertia = body.linear_velocity.length()*body.mass
		if (inertia >= inertia_tolerance):
			_destruct(collision_position, collision_normal, inertia/inertia_tolerance)


# Destructs and fractures this object. Call this method externally.
func _destruct(collision_point : Vector3, normal : Vector3, size : float):
	call_deferred("_destruct_deferred", collision_point, normal, size)


# Destructs this object. Preferably do not use this method externally.
func _destruct_deferred(collision_point : Vector3, normal : Vector3, size : float):
	if (can_destroy and destruction_pieces < max_destruction_pieces):
		emit_signal("on_destruct", collision_point)
		destruction_pieces += 1
		can_destroy = false
		
		# chunk mask
		var base_subtract = CSGMesh.new()
		base_subtract.name = "base_subtract"
		base_subtract.scale *= chunk_scale_adjustmenst*size
		base_subtract.mesh = self.chunk_mesh
		base_subtract.mesh.surface_set_material(0, underlying_material)
		base_subtract.material = underlying_material
		base_subtract.operation = CSGShape.OPERATION_SUBTRACTION
		base_subtract.scale /= collision_shape.scale
		base_subtract.translation.y -= 5000
		
		# remove mask from self base mesh
		csg_base.add_child(base_subtract)
		csg_base.global_transform.origin = global_transform.origin
		base_subtract.global_transform.origin = collision_point
		yield(get_tree(), "idle_frame") # wait for CSG operation to complete
		var shape : Shape
		if (set_rigid_on_max_destruction and destruction_pieces == max_destruction_pieces):
			mode = MODE_RIGID
			apply_central_impulse(chunk_explosiveness * mass * -(collision_point-global_transform.origin))
			shape = get_convex_shape_from_csg(csg_base)
		else:
			shape = get_concave_shape_from_csg(csg_base)
		collision_shape.set_shape(shape)
		
		## blow off chunk ##
		call_deferred("spawn_chunk", collision_point, normal, size)
		
		## prevent potentially costly destruction for a time ##
		yield(get_tree().create_timer(0.25), "timeout")
		can_destroy = true


# Spawns a new debris particle system.
func spawn_particles(position : Vector3):
	var particles = Particles.new()
	get_tree().current_scene.call_deferred("add_child", particles)
	particles.process_material = debris_particles
	particles.draw_pass_1 = debris_draw_instance
	particles.transform.origin = position
	particles.lifetime = particles_lifetime
	particles.explosiveness = 0.9
	particles.one_shot = true
	yield(get_tree().create_timer(particles.lifetime), "timeout")
	particles.queue_free()


# Spawns a chunk piece from this object.
func spawn_chunk(var collision_point : Vector3, normal : Vector3, size : float):
	var body = RigidBody.new()
	body.collision_layer = chunk_physics_layer
	body.collision_mask = chunk_physics_mask
	var chunk_base = CSGMesh.new()
	chunk_base.scale = csg_base.scale
	chunk_base.mesh = csg_base.mesh
	chunk_base.operation = CSGShape.OPERATION_UNION
	var chunk_subtract = CSGMesh.new()
	chunk_subtract.scale *= chunk_shrink_factor * chunk_scale_adjustmenst * size
	chunk_subtract.scale /= chunk_base.scale
	chunk_subtract.operation = CSGShape.OPERATION_INTERSECTION
	body.translation.y = 10000
	get_tree().current_scene.add_child(body)
	yield(get_tree(), "idle_frame")
	body.global_transform = global_transform
	body.add_child(chunk_base)
	chunk_base.add_child(chunk_subtract)
	
	chunk_subtract.mesh = self.chunk_mesh
	chunk_subtract.global_transform.origin = collision_point
	chunk_base.material = base_material
	chunk_subtract.material = underlying_material
	while chunk_base.get_meshes().empty(): yield(get_tree().create_timer(0.0), "timeout")
	
	var col = CollisionShape.new()
	col.disabled = true
	body.add_child(col)
	yield(get_tree(), "idle_frame") # wait for CSG operation
	col.set_shape(get_convex_shape_from_csg(chunk_base))
	col.scale = csg_base.scale
	
	# re-center rigid body more around chunk geometry
	var offset : Vector3 = -collision_point+global_transform.origin+normal*mesh_for_dimensions.get_aabb().get_longest_axis_size()/5
	body.global_transform.origin -= offset
	col.global_transform.origin += offset
	chunk_base.global_transform.origin += offset
	
	if (is_instance_valid(debris_particles)):
		call_deferred("spawn_particles", body.global_transform.origin)
	
	body.mass = mesh_for_dimensions.get_aabb().get_area()*chunk_density/2
	body.apply_central_impulse(normal*body.mass*chunk_explosiveness)
	col.disabled = false
	
	if (chunk_lifetime > 0.0):
		yield(get_tree().create_timer(chunk_lifetime), "timeout")
		body.queue_free()


# Calculates the concave shape of a CSGShape.
func get_concave_shape_from_csg(csg : CSGShape):
	var meshes : ArrayMesh = csg.get_meshes()[csg.get_meshes().size()-1]
	return meshes.create_trimesh_shape()


# Calculates the convex shape of a CSGShape.
func get_convex_shape_from_csg(csg : CSGShape):
	var meshes : ArrayMesh = csg.get_meshes()[csg.get_meshes().size()-1]
	return meshes.create_convex_shape()

