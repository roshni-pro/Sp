USE [shopkiranamutlimarketcentral]
GO
/****** Object:  StoredProcedure [Picker].[rejectedPickerReportExport]    Script Date: 20-09-2024 16:41:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--USE [shopkiranamutlimarketcentral]
--GO
--/****** Object:  StoredProcedure [Picker].[rejectedPickerReportExport]    Script Date: 16-07-2024 16:26:27 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

ALTER proc [Picker].[rejectedPickerReportExport]      
--declare       
 @warehouseids dbo.Intvalues readonly,      
 @Month int ,--=1,   ---last 1      
 @startdate datetime,-- = '2024-05-10',
 @enddate datetime ,--=  '2024-08-10',
 @isSelectedDate bit --=1
 --insert into @warehouseids values(1)    
 --insert into @warehouseids values(7)    
 --insert into @warehouseids values(213)    
as      
begin      
  if OBJECT_ID('tempdb..#temp') is not null drop table #temp  
  if OBJECT_ID('tempdb..#temp1') is not null drop table #temp1  
  if(@isSelectedDate = 0)
  begin
   ;with cte as (      
  select       
  wa.WarehouseName,      
  cast(pm.ModifiedDate as date) as ModifiedDate,      
  opd.OrderId     
  from OrderPickerDetails opd with(nolock)      
  inner join OrderPickerMasters pm  with(nolock) on pM.id=opd.OrderPickerMasterId      
  inner join Warehouses wa with(nolock) on wa.WarehouseId=pm.WarehouseId     
  inner join @warehouseids w on  w.IntValue=pm.WarehouseId    
  and opd.status = 3     
  and  Month(pm.ModifiedDate)= Month(dateadd(month, -@Month, getdate())) and year(pm.ModifiedDate)= year(dateadd(month, -@Month, getdate()))      
  group by wa.WarehouseName, opd.OrderId,pm.ModifiedDate )    
    
  select       
  cte.WarehouseName,      
  cte.ModifiedDate,      
  count(1) OrderCount    
  into #temp    
  from cte      
  group by cte.WarehouseName,cte.ModifiedDate      
      
  declare     
  @ListToPivot NVARCHAR(2000)     
  set  @ListToPivot=  '['+(Select  STRING_AGG(ModifiedDate ,'],[') from  (select distinct ModifiedDate from #temp) a ) +']'     
  print @ListToPivot    
    
  --select * from #temp    
    
  DECLARE @SqlStatement NVARCHAR(MAX)      
  SET @SqlStatement = N'    
  select * from #temp    
  pivot(    
   max(#temp.OrderCount) for #temp.ModifiedDate in ('+@ListToPivot+')    
  )AS PivotTable '    
    
  exec ( @SqlStatement)    
  
  end
  else
   begin
   ;with cte as (      
  select       
  wa.WarehouseName,      
  cast(pm.ModifiedDate as date) as ModifiedDate,      
  opd.OrderId     
  from OrderPickerDetails opd with(nolock)      
  inner join OrderPickerMasters pm  with(nolock) on pM.id=opd.OrderPickerMasterId      
  inner join Warehouses wa with(nolock) on wa.WarehouseId=pm.WarehouseId     
  inner join @warehouseids w on  w.IntValue=pm.WarehouseId    
  and opd.status = 3     
  --and  Month(pm.ModifiedDate)= Month(dateadd(month, -@Month, getdate())) and year(pm.ModifiedDate)= year(dateadd(month, -@Month, getdate()))      
     and (( @startdate = CAST(getdate() as date)  AND @enddate = CAST(getdate() as date) )OR ( cast(pm.ModifiedDate as date) >= cast(@startdate as date) and cast(pm.ModifiedDate as date) <= cast(@enddate as date)))
  group by wa.WarehouseName, opd.OrderId,pm.ModifiedDate )    
    
  select       
  cte.WarehouseName,      
  cte.ModifiedDate,      
  count(1) OrderCount    
  into #temp1    
  from cte      
  group by cte.WarehouseName,cte.ModifiedDate      
      
  declare     
  @ListToPivot1 NVARCHAR(2000)     
  set  @ListToPivot1=  '['+(Select  STRING_AGG(ModifiedDate ,'],[') from  (select distinct ModifiedDate from #temp1) a ) +']'     
  print @ListToPivot1    
    
  --select * from #temp    
    
  DECLARE @SqlStatement1 NVARCHAR(MAX)      
  SET @SqlStatement1 = N'    
  select * from #temp1    
  pivot(    
   max(#temp1.OrderCount) for #temp1.ModifiedDate in ('+@ListToPivot1+')    
  )AS PivotTable '    
    
  exec ( @SqlStatement1)    


  end

  -- ; with cte as (      
  --select       
  --wa.WarehouseName,      
  --pm.CreatedDate,      
  --opd.OrderId      
  --from OrderPickerDetails opd with(nolock)      
  --inner join OrderPickerMasters pm  with(nolock) on pM.id=opd.OrderPickerMasterId      
  --inner join Warehouses wa with(nolock) on wa.WarehouseId=pm.WarehouseId     
  --inner join @warehouseids w on  w.IntValue=pm.WarehouseId    
  --and opd.status = 3      
  ----and pm.WarehouseId in (213,1,7)      
  --and  Month(pm.CreatedDate)= Month(dateadd(month, -1, getdate())) and year(pm.CreatedDate)= year(dateadd(month, -1, getdate()))      
  --group by wa.WarehouseName, opd.OrderId, pm.CreatedDate)      
      
  --select       
  --cte.WarehouseName,      
  --Day(cte.CreatedDate),      
  --count(1) OrderCount      
  --from cte      
  --group by cte.WarehouseName,Day(cte.CreatedDate)      
  --order by cte.WarehouseName desc      
end
