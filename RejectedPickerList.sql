USE [shopkiranamutlimarketcentral]
GO
/****** Object:  StoredProcedure [Picker].[RejectedPickerList]    Script Date: 20-09-2024 16:42:46 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER proc [Picker].[RejectedPickerList]        
--Declare        
 @WarehouseIds dbo.Intvalues readonly,        
 @ClusterIds dbo.Intvalues readonly,        
 @FromDate datetime =NULL,        
 @ToDate datetime =NULL,       
 @skip int=0,        
 @take int=20,        
 @IsCount bit=1,        
 @keyword int =null --PICKER NO, ORDER nO           
AS        
Begin    
IF(@FromDate IS NULL OR @ToDate IS NULL)
BEGIN
SET @FromDate=dateadd(month,-1,getdate())
SET @ToDate =getdate()
END
	if(OBJECT_ID('tempdb..#temp') is not null) drop table #temp
	select distinct(ods.OrderId) as OrderIds,OrderPickerMasterId as Id into #temp from OrderPickerDetails ods with(nolock) where  ods.Status=3
 
 --insert into @WarehouseIds values(1)  
 --insert into @WarehouseIds values(7)  
 --insert into @ClusterIds values(46)  
 --insert into @ClusterIds values(47)  
 --insert into @ClusterIds values(48)  
 --insert into @ClusterIds values(49)  
 -- insert into @ClusterIds values(50)  
 if(@IsCount=1 and @FromDate is not null and @ToDate is not null)        
   begin 
   ;with cte as(    
    select           
    PM.Id as PickerNumber,        
    p.DisplayName  as PickerpersonName,        
    sp.DisplayName as InventorySupNAme,        
    count(distinct opd.OrderId) NoOfOrders,        
    PM.CreatedDate,               
    case when (opd.Status=3 or pm.IsCanceled =1) then  mp.DisplayName else '' end as RejectedBy,        
    case when (opd.Status=3 or pm.IsCanceled =1) and PM.ModifiedDate Is not null then  PM.ModifiedDate else null end as RejectedDate,        
    sum(opd.Qty) as LineItemQuantity,
    od.order1 as OrderNumber ,
	(sum(opd.Qty*(ordd.UnitPrice))) as amt,
	wh.WarehouseName,
	pm.WarehouseId
    from OrderPickerMasters PM with(nolock)        
	inner join @WarehouseIds w on  w.IntValue=pm.WarehouseId
	left join @ClusterIds clids on  clids.IntValue=pm.ClusterId       
    inner join OrderPickerDetails opd with(nolock) on pM.id=opd.OrderPickerMasterId
	inner join OrderDetails ordd with(nolock) on ordd.OrderDetailsId=opd.OrderDetailsId
	left join Warehouses wh with(nolock) on  wh.WarehouseId=pm.WarehouseId
    cross apply(select STRING_AGG(odd.OrderIds,',') as order1 from(select OrderIds from #temp with(nolock) where Id=pm.Id)odd)od        
	outer apply( select top 1 pp.DisplayName from People pp with(nolock) where pp.PeopleID=pm.PickerPersonId)p        
    outer apply( select top 1  spp.DisplayName from People spp with(nolock) where spp.PeopleID=pm.InventorySupervisorId)sp        
    outer apply( select top 1  mpp.DisplayName from People mpp with(nolock) where mpp.PeopleID=opd.ModifiedBy)mp        
    where opd.Status=3 and ((@FromDate is null and  @ToDate is null) or (pm.ModifiedDate between @FromDate and DATEADD(day, 1, @ToDate))) 
    and ((@keyword is null) or (pm.Id=cast(@keyword as bigint)) or (opd.OrderId=cast(@keyword as int) ))        
    group by  opd.Status,PM.Id, PM.CreatedDate,p.DisplayName,sp.DisplayName , pm.Comment,mp.DisplayName,PM.ModifiedDate,
	pm.IsCanceled,od.order1,wh.WarehouseName,pm.WarehouseId        
    --order by pm.Id Desc     
)  
	select * from cte
	--select *, (ToAmt-omm.Addamt) as amt from cte  
	--outer apply(select top 1 sum((isnull(om.WalletAmount,0))+(isnull(om.BillDiscountAmount,0))-(isnull(om.deliveryCharge,0)))  Addamt
	--   from  OrderMasters om with(nolock) where om.OrderId in (select item from dbo.SplitString(cte.OrderNumber,',')))omm          
   end        
 else 
   begin        
    ;with cte as(select           
    PM.Id as PickerNumber,        
    p.DisplayName  as PickerpersonName,        
    sp.DisplayName as InventorySupNAme,        
    count(distinct opd.OrderId) NoOfOrders,        
    PM.CreatedDate,               
    case when (opd.Status=3 or pm.IsCanceled =1) then  mp.DisplayName else '' end as RejectedBy,        
    case when (opd.Status=3 or pm.IsCanceled =1) and PM.ModifiedDate Is not null then  PM.ModifiedDate else null end as RejectedDate,        
    sum(opd.Qty) as LineItemQuantity,
    od.order1 as OrderNumber ,
	(sum(opd.Qty*(ordd.UnitPrice))) as amt,
	wh.WarehouseName,
	pm.WarehouseId
    from OrderPickerMasters PM with(nolock)        
	inner join @WarehouseIds w on  w.IntValue=pm.WarehouseId
	left join @ClusterIds clids on  clids.IntValue=pm.ClusterId       
    inner join OrderPickerDetails opd with(nolock) on pM.id=opd.OrderPickerMasterId  
	inner join OrderDetails ordd with(nolock) on ordd.OrderDetailsId=opd.OrderDetailsId

	left join Warehouses wh with(nolock) on  wh.WarehouseId=pm.WarehouseId
    cross apply(select STRING_AGG(odd.OrderIds,',') as order1 from(select OrderIds from #temp with(nolock) where Id=pm.Id)odd)od        
	outer apply( select top 1 pp.DisplayName from People pp with(nolock) where pp.PeopleID=pm.PickerPersonId)p        
    outer apply( select top 1  spp.DisplayName from People spp with(nolock) where spp.PeopleID=pm.InventorySupervisorId)sp        
    outer apply( select top 1  mpp.DisplayName from People mpp with(nolock) where mpp.PeopleID=opd.ModifiedBy)mp        
    where opd.Status=3 and ((@FromDate is null and  @ToDate is null) or (pm.ModifiedDate between @FromDate and DATEADD(day, 1, @ToDate))) 
    and ((@keyword is null) or (pm.Id=cast(@keyword as bigint)) or (opd.OrderId=cast(@keyword as int) ))        
    group by  opd.Status,PM.Id, PM.CreatedDate,p.DisplayName,sp.DisplayName , pm.Comment,mp.DisplayName,PM.ModifiedDate,
	pm.IsCanceled,od.order1,wh.WarehouseName,pm.WarehouseId        
    order by pm.Id Desc
    OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY   
	)  
	select * from cte
	--select *, (ToAmt-omm.Addamt) as amt from cte  
	--outer apply(select top 1 sum((isnull(om.WalletAmount,0))+(isnull(om.BillDiscountAmount,0))-(isnull(om.deliveryCharge,0)))  Addamt
	--   from  OrderMasters om with(nolock) where om.OrderId in (select item from dbo.SplitString(cte.OrderNumber,',')))omm
    select           
    count(distinct pm.Id)        
    from OrderPickerMasters PM with(nolock)        
	inner join @WarehouseIds w on  w.IntValue=pm.WarehouseId
	left join @ClusterIds clids on  clids.IntValue=pm.ClusterId       
    inner join OrderPickerDetails opd with(nolock) on pM.id=opd.OrderPickerMasterId  
	left join Warehouses wh with(nolock) on  wh.WarehouseId=pm.WarehouseId
	where opd.Status=3 and ((@FromDate is null and  @ToDate is null) or (pm.ModifiedDate between @FromDate and DATEADD(day, 1, @ToDate))) 
    and ((@keyword is null) or (pm.Id=cast(@keyword as bigint)) or (opd.OrderId=cast(@keyword as int) ))   
    end        
end
