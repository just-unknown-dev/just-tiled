<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.10.2" name="terrain" class="Ground" tilewidth="16" tileheight="16" tilecount="16" columns="4" objectalignment="bottom" tilerendersize="grid" fillmode="preserve-aspect-fit">
 <grid orientation="orthogonal" width="16" height="16"/>
 <properties>
  <property name="biome" value="forest"/>
 </properties>
 <image source="../terrain.png" width="64" height="64"/>
 <tile id="2" type="Wall"/>
 <wangsets>
  <wangset name="Road" type="edge" tile="-1">
   <wangcolor name="road" color="#aaaaaa" tile="-1" probability="1"/>
   <wangtile tileid="0" wangid="1,0,0,0,1,0,0,0"/>
   <wangtile tileid="1" wangid="0,0,1,0,0,0,1,0"/>
  </wangset>
  <wangset name="Mixed" type="mixed" tile="4">
   <properties>
    <property name="note" value="both"/>
   </properties>
   <wangcolor name="water" color="#3366ff" tile="4" probability="2"/>
   <wangcolor name="sand" color="#eecc88" tile="5" probability="1"/>
   <wangtile tileid="4" wangid="1,1,1,1,1,1,1,1"/>
   <wangtile tileid="5" wangid="2,2,2,2,2,2,2,2"/>
   <wangtile tileid="6" wangid="1,1,2,2,2,2,2,1"/>
  </wangset>
 </wangsets>
</tileset>
