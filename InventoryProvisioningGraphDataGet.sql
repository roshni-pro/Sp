USE [shopkiranamutlimarketcentral]
GO
/****** Object:  StoredProcedure [dbo].[InventoryProvisioningGraphDataGet]    Script Date: 20-09-2024 17:03:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER proc [dbo].[InventoryProvisioningGraphDataGet] 
--declare
   @FromDate datetime
  ,@ToDate datetime
  ,@warehouseIdList dbo.intvalues readonly 
  ,@brandIdList dbo.intvalues readonly 
as  
begin  

	
	declare @endDate date = (select max(cast(createddate as date)) from inqueue) 
	declare @startDate date = cast(year(@enddate) as varchar(4)) + '-' + cast(month(@enddate) as varchar(2)) + '-01' 

	DECLARE @thisMonthFirstDate datetime =  CAST(DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1) as datetime);

	IF OBJECT_ID(N'tempdb..#tempInventroyData') IS NOT NULL  
			DROP TABLE #tempInventroyData;   


	select	   D.WarehouseId
			  ,D.ItemMultiMRPId	
			  ,D.CalculationDate
			  ,SUM(D.ClosingAmount) * pcd.Percentage	/ 100.0  ProvisioningAmount
	into #tempInventroyData
	from InventroyProvisioningDatas D
	inner join ItemMultiMRPs b with(nolock) on d.ItemMultiMrpId = b.ItemMultiMRPId   
	
	cross apply (
			select top 1  c.SubsubCategoryid 
						 ,itemname as itemBaseName
					     ,Number 
						 ,Categoryid 
			from ItemMasterCentrals c 
			where c.Number = b.ItemNumber
			and c.active =1 
			and c.Deleted =0
	)brand
	inner join @warehouseIdList W ON D.WarehouseId = W.IntValue
	inner join InventroyProvisioningConfigurations C
		ON D.AgingDays >= C.FromDays AND D.AgingDays <= C.ToDays and c.IsActive=1 and C.IsDeleted=	0
	inner join InventroyProvisioningConfigurationDetails pcd on pcd.InventroyProvisioningConfigurationId = C.Id and pcd.IsActive=1 and pcd.IsDeleted=0 and pcd.CategoryId = brand.Categoryid
		
	WHERE EXISTS (
		SELECT 1
		FROM ItemMasters C 
		inner join @brandIdList B ON C.SubsubCategoryid = B.IntValue
		and C.active =1 and C.Deleted =0
		WHERE C.WarehouseId = W.IntValue 
	)	
	and D.CalculationDate >= @FromDate and D.CalculationDate <= @ToDate 
	group by   D.WarehouseId
			  ,D.ItemMultiMRPId	
			  ,pcd.Percentage
			  ,D.CalculationDate	 

	IF(@FromDate<= @thisMonthFirstDate AND @ToDate >= @thisMonthFirstDate)
	BEGIN
		insert into #tempInventroyData
		select 
			 innerData.WarehouseId
			,innerData.ItemMultiMrpId
			,cast(@thisMonthFirstDate as date) CalculationDate
			,ISNULL((innerData.ClosingAmount * pcd.Percentage / 100.0), 0) ProvisioningAmount
		from (  
			 select  a.ItemMultiMrpId
					,W.WarehouseId
					,case when cast(InDate as date) is not null then cast(InDate as date) else cast(a.CreatedDate as date) end InDate
					,Datediff(
						Day
						,case when cast(InDate as date) is not null then cast(InDate as date) else cast(a.CreatedDate as date) end 
						,cast(getdate() as date)
					) Ageing
					,sum(remqty * price) ClosingAmount   
					,brand.Categoryid
			 from InQueue a  with(nolock)
			 inner join @warehouseIdList wa on a.WarehouseId = wa.IntValue  
			 inner join ItemMultiMRPs b with(nolock) on a.ItemMultiMrpId = b.ItemMultiMRPId   
			 cross apply (
				select top 1  c.SubsubCategoryid 
							 ,itemname as itemBaseName
							 ,Number
							 ,Categoryid
				from ItemMasters c 
				where c.ItemMultiMRPId = b.ItemMultiMRPId
				and c.Deleted =0
			 )brand
			 inner join @brandIdList bl on brand.SubsubCategoryid = bl.IntValue
			 join Warehouses W  with(nolock)on W.WarehouseId=a.WarehouseId  
			 where (remqty >0) 
				  and cast(a.CreatedDate as date) between @startDate and @endDate	
				  and W.active =1 and W.Deleted =0
				--and month(a.CreatedDate) =@month 
				--and year(a.CreatedDate)=@year  
			 group by a.ItemMultiMrpId
					,W.WarehouseId
					,cast(a.CreatedDate as date)
					,cast(InDate as date)  
					,brand.Categoryid
		)innerData
		inner join InventroyProvisioningConfigurations conf
			on innerData.Ageing >=  conf.FromDays and innerData.Ageing <=  conf.ToDays 
			and conf.IsActive=1 and conf.IsDeleted=0 
	inner join InventroyProvisioningConfigurationDetails pcd 
		on pcd.InventroyProvisioningConfigurationId = conf.Id 
		and pcd.IsActive=1 and pcd.IsDeleted=0 and pcd.CategoryId = innerData.Categoryid
		

	END

	select   W.WarehouseName,
			 D.CalculationDate,
			 round(SUM(D.ProvisioningAmount), 2) ProvisioningAmount
	from #tempInventroyData D
	inner join Warehouses W ON D.WarehouseId = W.WarehouseId
	group by D.WarehouseId,
			 W.WarehouseName,	
			 D.CalculationDate
	order by D.WarehouseId, D.CalculationDate


end  


