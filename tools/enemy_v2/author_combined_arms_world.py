"""Build the mixed 414 army into a reviewable workspace file; publication is separate."""
import argparse, copy, json, math, os
from pathlib import Path

def build(source: Path, output: Path):
    data=json.loads(source.read_text(encoding='utf8'))
    old_groups=[e for e in data['entities'] if e['type']=='enemy_group']
    template=copy.deepcopy(old_groups[0])
    data['entities']=[e for e in data['entities'] if e['type']!='enemy_group']
    terrains=[e for e in data['entities'] if e['type']=='terrain']
    center=(29.0,-101.0)
    def ground(x,z):
        for e in terrains:
            p=e['properties']; tx,ty,tz=e['position']; w=p['width']; d=p['depth']; n=p['resolution']
            if not(tx-w/2<=x<=tx+w/2 and tz-d/2<=z<=tz+d/2): continue
            gx=(x-tx+w/2)/w*(n-1); gz=(z-tz+d/2)/d*(n-1)
            ix=min(n-2,math.floor(gx)); iz=min(n-2,math.floor(gz)); u=gx-ix; v=gz-iz; h=p['heights']
            return ty+(h[iz*n+ix]*(1-u)+h[iz*n+ix+1]*u)*(1-v)+(h[(iz+1)*n+ix]*(1-u)+h[(iz+1)*n+ix+1]*u)*v
        return 0.0
    for e in data['entities']:
        if e['type']=='player_spawn': e['position']=[center[0],ground(*center)+0.15,center[1]]
    xs=[-30,-10,10,30]
    def group(id,label,role,count,x,z,lane,columns=4):
        e=copy.deepcopy(template); e['id']=id; e['name']=label
        wx=center[0]+x; wz=center[1]+z
        e['position']=[wx,ground(wx,wz)+0.04,wz]; e['rotation']=[0,0,0]
        archetype={'phalanx':'enemy_v2_hoplite','archer':'enemy_v2_archer','infantry':'enemy_v2_infantry','giant':'enemy_v2_giant','skirmish':'enemy_v2_hoplite_veteran'}[role]
        mode='hoplite_phalanx' if role=='phalanx' else ('hoplite_skirmish' if role=='skirmish' else role)
        fx=center[0]+xs[lane]; fz=center[1]-15
        p=e['properties']
        p.update(group_id=id,archetype=archetype,count=count,composition=[{'archetype':archetype,'count':count}],
                 rank='miniboss' if role=='giant' else 'normal',size_multiplier=3.0 if role=='giant' else 1.0,
                 formation='phalanx',formation_columns=columns,formation_spacing=1.6 if role=='archer' else 1.2,
                 formation_rank_spacing=1.4 if role=='archer' else 1.1,
                 behavior='normal',route_id='',protect_target='',spawn_condition='start',spawn_delay=0.0,
                 deployment_mode='all',v2_troop_mode=mode,v2_unit_role='infantry' if role=='skirmish' else role,
                 v2_battle_role='ranged' if role=='archer' else ('giant' if role=='giant' else 'frontline'),
                 v2_persistent_fronts=True,v2_front_id=lane,v2_front_origin=[fx,ground(fx,fz),fz],v2_front_forward=[0,0,1],
                 v2_combat_lab=True,v2_command_lab=True,v2_animation='idle',performance_profile='auto')
        # Old authored speeds/attack counts must not override the role profile.
        for key in ['v2_phalanx_advance_speed','v2_max_concurrent_attacks']: p.pop(key,None)
        data['entities'].append(e)
    for rank,z in enumerate([-19,-38,-78]):
        for lane,x in enumerate(xs):
            group(f'front_phalanx_{lane}_{rank}',f'Front {lane+1} — Phalange {rank+1}', 'phalanx',24,x+(-2 if rank==2 else 2 if rank==1 else 0),z,lane,8)
    # Open intervals between phalanxes; two mobile reserves remain in depth.
    for i,(x,z,lane) in enumerate([(-20,-12,0),(0,-11,1),(20,-12,2),(-43,-31,0),(-22,-82,1),(18,-82,2)]):
        group(f'front_infantry_{i}',f'Fantassins — aile {i+1}','infantry',12,x,z,lane)
    for i,(x,z,lane) in enumerate([(-5,-25,1),(5,-25,2),(-43,-70,0),(54,-59,3)]):
        group(f'front_archer_{i}',f'Archers — soutien {i+1}','archer',12,x,z,lane)
    group('front_veterans','Avant-garde — 4 vétérans','skirmish',4,0,-4,1,2)
    for i,x in enumerate([-18,22]):
        group(f'front_giant_{i}',f'Géant — aile {i+1}','giant',1,x,-43,0 if i==0 else 3,1)
    # Keep all authored props, but clear military deployment avenues. Barricades
    # and rocks remain playable on the two flanks instead of inside spawn ranks.
    shifted=0
    for e in data['entities']:
        if e['type']!='prop' or not e.get('properties',{}).get('collision_enabled',False): continue
        x,y,z=e['position']
        archer_block=e['id'] in {'prop_3861566512_295','prop_3863422248_859','prop_3859119213_124'}
        if archer_block or (center[1]-88 < z < center[1]+3 and center[0]-51 < x < center[0]+51):
            lane_block=any(abs(x-(center[0]+lane_x))<8 for lane_x in xs)
            aux_block=any((x-(center[0]+ax))**2+(z-(center[1]+az))**2<64 for ax,az in [(-43,-17),(43,-17),(-43,-70),(43,-70),(-20,-29),(20,-29)])
            if archer_block or lane_block or aux_block:
                nx=center[0]+(-73 if x<center[0] else 73)+(shifted%2)*3
                nz=z+(shifted%3-1)*2
                e['position']=[nx,ground(nx,nz),nz]
                shifted+=1
    data['settings']['enemy_v2_relocated_deployment_props']=shifted
    data['name']='champsDeBataille_V2_Commandement_414'
    data['settings']['enemy_v2_expected_population']=414
    data['settings']['enemy_v2_combined_arms']=True
    data['settings']['enemy_lod_override']={'enabled':True,'near_distance':10.0,'far_distance':26.0,'cull_distance':65.0,'full_rate_distance':3.0,'medium_animation_hz':24.0,'far_animation_hz':10.0,'shadow_distance':5.5}
    assert sum(e['properties']['count'] for e in data['entities'] if e['type']=='enemy_group')==414
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')),encoding='utf8')
    print(f'COMBINED_ARMS_AUTHORED {output} population=414 phalanx=288 infantry=72 archer=48 veterans=4 giant=2')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--source',type=Path,default=Path(os.environ['APPDATA'])/'Godot/app_userdata/Project Hoplite - UAL Native Combat Lab/hoplite_worlds/champsdebataille_v2_commandement_414.hoplite.json')
    parser.add_argument('--output',type=Path,default=Path('.tmp_tools/champsdebataille_v2_commandement_414.hoplite.json'))
    args=parser.parse_args(); build(args.source,args.output)
