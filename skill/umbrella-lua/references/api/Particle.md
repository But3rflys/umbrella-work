# Particle
Table to work with particles.

Particle.Create(particle: string, [attach_type: Enum.ParticleAttachment = Enum.ParticleAttachment.PATTACH_WORLDORIGIN], [entity: CEntity = Players.GetLocal()]) -> integer
  Creates a particle and returns its index.
  particle: Particle path
  attach_type: attach_type Attach type
  entity: Entity to own of the particle. If not specified, the local hero will be used.
Particle.SetControlPoint(particle_index: integer, control_point: integer, value: Vector)
  Sets the control point value of a particle.
  particle_index: Particle index
  control_point: Control point
  value: Control point value
Particle.SetShouldDraw(particle_index: integer, value: boolean)
  Enables or disables the drawing of a particle.
  particle_index: Particle index
  value: set value
Particle.SetControlPointEnt(particle_index: integer, control_point: integer, entity: CEntity, attach_type: Enum.ParticleAttachment, attach_name: string|nil, position: Vector, lock_orientation: boolean)
  Sets the control point entity value of a particle.
  particle_index: Particle index
  control_point: Control point
  entity: Entity to attach
  attach_type: Attach type
  attach_name: Attach name. See NPC.GetAttachment function
  position: Control point position
  lock_orientation: Lock orientation. No idea what it does
Particle.SetParticleControlTransform(particle_index: integer, control_point: integer, position: Vector, angle: Angle)
  Sets the control point's position and angle.
  particle_index: Particle index
  control_point: Control point
  position: Control point position
  angle: Control point angle
Particle.Destroy(particle_index: integer)
  Destroys the particle by index.
  particle_index: Particle index
