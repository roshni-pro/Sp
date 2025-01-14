USE [shopkiranamutlimarketcentral]
GO
/****** Object:  StoredProcedure [Picker].[rejectedPickerReport]    Script Date: 20-09-2024 16:42:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER proc [Picker].[rejectedPickerReport]  
--declare       
  @warehouseids dbo.Intvalues readonly,    
 @Allwarehouseids dbo.Intvalues readonly,
 @startdate datetime,-- = '2024-06-10',
 @enddate datetime -- =  '2024-06-10'
 --insert into @warehouseids values(213)    
 --insert into @warehouseids values(1)    
 --insert into @Allwarehouseids
 --select WarehouseId from Warehouses where active = 1
as
begin   
	--insert into @Allwarehouseids
	--select WarehouseId from Warehouses where active = 1 --and WarehouseId = 9
	--insert into @warehouseids
	--select WarehouseId from Warehouses where active = 1 --and WarehouseId = 9
 if OBJECT_ID('tempdb..#temp') is not null drop table #temp    
  --;with cte as (      
  select       
  opd.OrderId,      
  pm.ModifiedDate,      
  wa.WarehouseName     
  into #temp    
  from OrderPickerDetails opd with(nolock)      
  inner join OrderPickerMasters pm  with(nolock) on pM.id=opd.OrderPickerMasterId    
  inner join @WarehouseIds w  on  w.IntValue=pm.WarehouseId     
  inner join Warehouses wa with(nolock) on wa.WarehouseId = pm.WarehouseId      
    
  and opd.status = 3  and  pm.ModifiedDate>= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0) --and  Month(pm.ModifiedDate)>= Month(dateadd(month, -1, getdate())) and year(pm.ModifiedDate)>= year(dateadd(month, -1, getdate()))      
 --and (( @startdate = CAST(getdate() as date)  AND @enddate = CAST(getdate() as date) )OR ( cast(pm.ModifiedDate as date) >= cast(@startdate as date) and cast(pm.ModifiedDate as date) <= cast(@enddate as date)))
  group by wa.WarehouseName, opd.OrderId,      
  pm.ModifiedDate	

 if OBJECT_ID('tempdb..#temp2') is not null drop table temp2    
  --;with cte as (      
  select       
  opd.OrderId,      
  wa.WarehouseName     
  into #temp2    
  from OrderPickerDetails opd with(nolock)      
  inner join OrderPickerMasters pm  with(nolock) on pM.id=opd.OrderPickerMasterId    
  inner join @WarehouseIds w  on  w.IntValue=pm.WarehouseId     
  inner join Warehouses wa with(nolock) on wa.WarehouseId = pm.WarehouseId      
  and opd.status = 3  and ((@startdate = @enddate AND  pm.ModifiedDate>= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0))OR(pm.ModifiedDate >= @startdate AND pm.ModifiedDate <= @enddate))
  group by wa.WarehouseName, opd.OrderId

 -- if(cast(@startdate as date) != cast(GETDATE() as date) and cast(@enddate as date) != cast(GETDATE() as date))
 -- begin
 -- if OBJECT_ID('tempdb..#tempData') is not null drop table #tempData 
 -- select   opd.OrderId,      
 -- pm.ModifiedDate,      
 -- wa.WarehouseName  into #tempData 
 -- from OrderPickerMasters pm
 --inner join OrderPickerDetails opd on pm.Id = opd.OrderPickerMasterId
 --inner join @WarehouseIds w  on  w.IntValue=pm.WarehouseId     
 -- inner join Warehouses wa with(nolock) on wa.WarehouseId = pm.WarehouseId      
 -- and opd.status = 3  and  pm.ModifiedDate>= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0) --and  Month(pm.ModifiedDate)>= Month(dateadd(month, -1, getdate())) and year(pm.ModifiedDate)>= year(dateadd(month, -1, getdate()))      
 --where 
 --(( @startdate = CAST(getdate() as date)  AND @enddate = CAST(getdate() as date) )OR ( cast(pm.ModifiedDate as date) >= cast(@startdate as date) and cast(pm.ModifiedDate as date) <= cast(@enddate as date)))
 --group by wa.WarehouseName, opd.OrderId      
 -- ,pm.ModifiedDate

 --select * from #tempData
 -- end
  if(select count(*) from @Allwarehouseids) > 0
  begin

  ;with cte as (      
  select       
  opd.OrderId,      
  pm.ModifiedDate     
  from OrderPickerDetails opd with(nolock)      
  inner join OrderPickerMasters pm  with(nolock) on pM.id=opd.OrderPickerMasterId    
  inner join @Allwarehouseids w  on  w.IntValue=pm.WarehouseId     
  and opd.status = 3 
  and  pm.ModifiedDate>= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0) -- and  Month(pm.ModifiedDate)>= Month(dateadd(month, -1, getdate())) and year(pm.ModifiedDate)>= year(dateadd(month, -1, getdate()))      
  --and (( @startdate = CAST(getdate() as date)  AND @enddate = CAST(getdate() as date) )OR ( cast(pm.ModifiedDate as date) >= cast(@startdate as date) and cast(pm.ModifiedDate as date) <= cast(@enddate as date)))
  group by  opd.OrderId,      
  pm.ModifiedDate)    
    
 select       
 count(case when Month(ModifiedDate)=month(GETDATE()) then 1 else null end) currentMonthCount,      
 count(case when Month(ModifiedDate)!=month(GETDATE()) then 1 else null end) lastMonthCount,      
 count(case when cast(ModifiedDate as Date)=Cast(GETDATE() as Date) then 1 else null end) todayCount  ,    
  -- count(case when (cast(ModifiedDate as date) >= cast(@startdate as date) 
  --and cast(ModifiedDate as date) <= cast(@enddate as date)
  --) then 1 else null end) selectedDateCount ,
  MAX(X.ordCount) as selectedDateCount,
 'All' WarehouseName      
 from cte    
 OUTER APPLY (
	SELECT COUNT(t2.OrderId) ordCount
	FROM #temp2 t2 
 )X   
 union all    
    
 select       
 count(case when Month(tp.ModifiedDate)=month(GETDATE()) then 1 else null end) currentMonthCount,      
 count(case when Month(tp.ModifiedDate)!=month(GETDATE()) then 1 else null end) lastMonthCount,      
 count(case when cast(tp.ModifiedDate as Date)=Cast(GETDATE() as Date) then 1 else null end) todayCount ,    
  -- count(case when (cast(tp.ModifiedDate as date) >= cast(@startdate as date) 
  --and cast(tp.ModifiedDate as date) <= cast(@enddate as date)
  --) then 1 else null end) selectedDateCount ,
  MAX(X.ordCount) selectedDateCount, 
 tp.WarehouseName      
 from #temp tp      
  OUTER APPLY (
	SELECT COUNT(t2.OrderId) ordCount
	FROM #temp2 t2
	where tp.WarehouseName = t2.WarehouseName
	group by t2.WarehouseName 
 )X 
 group by tp.WarehouseName 
  end
  else
  begin
   select       
 count(case when Month(tp.ModifiedDate)=month(GETDATE()) then 1 else null end) currentMonthCount,      
 count(case when Month(tp.ModifiedDate)!=month(GETDATE()) then 1 else null end) lastMonthCount,      
 count(case when cast(tp.ModifiedDate as Date)=Cast(GETDATE() as Date) then 1 else null end) todayCount ,    
  --count(case when (cast(tp.ModifiedDate as date) >= cast(@startdate as date) 
  --and cast(tp.ModifiedDate as date) <= cast(@enddate as date)
  
  ----cast(tp.ModifiedDate as Date)=Cast(GETDATE() as Date
  --) then 1 else null end) selectedDateCount ,    
    MAX(X.ordCount) selectedDateCount, 
 tp.WarehouseName      
 from #temp tp    
 OUTER APPLY (
	SELECT COUNT(t2.OrderId) ordCount
	FROM #temp2 t2
	where tp.WarehouseName = t2.WarehouseName
	group by t2.WarehouseName 
 )X
 group by tp.WarehouseName 

  
  end
  end