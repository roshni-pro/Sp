USE [shopkiranamutlimarketcentral]
GO
/****** Object:  StoredProcedure [dbo].[GetInventoryProvisioningData]    Script Date: 20-09-2024 17:02:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER proc [dbo].[GetInventoryProvisioningData] 
--declare
   @calcultionDate datetime ='2023-05-01'
  ,@warehouseId int
  ,@brandIdList dbo.intvalues readonly 
  ,@Keyword varchar(100) = ''
as  
begin  
	
	declare @endDate date = (select max(cast(createddate as date)) from inqueue) 
	declare @startDate date = cast(year(@enddate) as varchar(4)) + '-' + cast(month(@enddate) as varchar(2)) + '-01' 

	declare  @cols nvarchar(MAX)
		   , @colsWithMax nvarchar(MAX) = ''
		   , @colsWithMaxAndName nvarchar(MAX)
		   , @query nvarchar(MAX);
	
	IF OBJECT_ID(N'tempdb..#tempInventoryProvisioningData') IS NOT NULL  
		DROP TABLE #tempInventoryProvisioningData;   
	
	IF OBJECT_ID(N'tempdb..#tempNameWithMaxColumns') IS NOT NULL  
		DROP TABLE #tempNameWithMaxColumns;  
	
	IF OBJECT_ID(N'tempdb..#cte') IS NOT NULL  
		DROP TABLE #cte;  

	IF OBJECT_ID(N'tempdb..#tempFrontMargin') IS NOT NULL  
		DROP TABLE #tempFrontMargin;  

	
	IF OBJECT_ID(N'tempdb..#tempInventroyProvisioningConfig1') IS NOT NULL  
		DROP TABLE #tempInventroyProvisioningConfig1; 

	
	IF OBJECT_ID(N'tempdb..#tempInventroyProvisioningConfig2') IS NOT NULL  
		DROP TABLE #tempInventroyProvisioningConfig2; 

	create table #tempInventroyProvisioningConfig1 (name nvarchar(max), fromDats int, isProcess bit )
	create table #tempInventroyProvisioningConfig2 (name nvarchar(max))
	
	Declare @warehousetbl table (warehouseid int, warehousename varchar(200))
	Insert into @warehousetbl
	select w.warehouseid, w.WarehouseName 
	from Warehouses w with(nolock) 
	inner join GMWarehouseProgresses b with(nolock) on w.WarehouseId = b.WarehouseID and b.IsLaunched=1
		and w.active=1 and w.Deleted=0 and w.IsKPP=0 and w.CityName not like '%test%' 


	insert into #tempInventroyProvisioningConfig1 (name, fromDats , isProcess ) 
	select name ,  fromDays, cast(0 as bit) from  InventroyProvisioningConfigurations 
	declare @name nvarchar(max) = '';

	select top 1 @name = name from #tempInventroyProvisioningConfig1  where isProcess =0 order by fromDats

	declare @counter1 int  =1;
	WHILE(ISNULL(@name ,  '') != '' )
	BEGIN
		insert into #tempInventroyProvisioningConfig2  (name) values (@name);
		
		if(@counter1 = 1)
		BEGIN
			SET @colsWithMaxAndName = ISNULL(@colsWithMaxAndName , '') + 'MAX([' + @name + ']) as [' + @name + ']' 	
		END
		ELSE 
		BEGIN
			SET @colsWithMaxAndName = ISNULL(@colsWithMaxAndName , '') + ',' + 'MAX([' + @name + ']) as [' + @name + ']' 	
		END
		SET @counter1 = @counter1+1;
		update #tempInventroyProvisioningConfig1  set isProcess =1 where name = @name;
		--select * from #tempInventroyProvisioningConfig1
		set @name = '';
		select top 1 @name= name from #tempInventroyProvisioningConfig1  where isProcess =0 order by fromDats

	END


	SET @colsWithMax = STUFF((SELECT distinct '),MAX(' + QUOTENAME(c.Name) 
            FROM #tempInventroyProvisioningConfig2 c

			FOR XML PATH(''), TYPE
            
			).value('.', 'NVARCHAR(MAX)') 
        ,1,1,''  );

	set @colsWithMax = @colsWithMax + ')'

	SET @cols = STUFF((SELECT distinct ',' + QUOTENAME(c.Name) 
				FROM #tempInventroyProvisioningConfig2 c

				FOR XML PATH(''), TYPE
            
				).value('.', 'NVARCHAR(MAX)') 
			,1,1,''  );



	select  X.Item + ' as ' + Z.Item  as NameWithMax 
	INTO #tempNameWithMaxColumns
	from SplitString(@colsWithMax, ',') X
	cross apply  (
		select  * from SplitString(@cols, ',') Y
		WHERE X.Item  =  'MAX(' +Y.Item + ')'	

	)Z




	 
	select 
		 innerData.WarehouseId
		,innerData.WarehouseName
		,innerData.ItemMultiMrpId
		,innerData.MRP
		,innerData.itemBaseName
		,innerData.ClosingQty
		,innerData.ClosingAmount
		,round(ISNULL((innerData.ClosingAmount * pcd.Percentage / 100.0), 0),2) CurrentProvisioning
		,innerData.Number
		,conf.Name Id
		,pcd.Percentage
	into #tempInventoryProvisioningData
	from (  
		 select  W.WarehouseName
				,a.ItemMultiMrpId
				,b.MRP
				,a.WarehouseId
				,brand.itemBaseName
				,brand.Number
				,brand.Categoryid
				,case when cast(InDate as date) is not null then cast(InDate as date) else cast(a.CreatedDate as date) end InDate
				,Datediff(
					Day
					,case when cast(InDate as date) is not null then cast(InDate as date) else cast(a.CreatedDate as date) end 
					,cast(getdate() as date)
				) Ageing
				,sum(remqty) ClosingQty
				,sum(remqty * price) ClosingAmount   
		 from InQueue a  with(nolock)  
		 inner join ItemMultiMRPs b with(nolock) on a.ItemMultiMrpId = b.ItemMultiMRPId   
		 cross apply (
			select top 1  c.SubsubCategoryid 
						 ,itemname as itemBaseName
					     ,Number 
						 ,Categoryid 
			from ItemMasterCentrals c  with(nolock)  
			where c.Number = b.ItemNumber			
			and c.Deleted =0
			and (ISNULL(@Keyword, '') = '' OR itemname like '%' + @Keyword + '%' OR Number like '%' + @Keyword + '%')
		 )brand
		 inner join @brandIdList bl on brand.SubsubCategoryid = bl.IntValue
		 
		 join @warehousetbl W on W.WarehouseId=a.WarehouseId  
		 where (remqty >0) 
			  and (@warehouseId	=0 or a.WarehouseId = @warehouseId	)
			--and month(a.CreatedDate) =@month 
			--and year(a.CreatedDate)=@year  
			  and cast(a.CreatedDate as date) between @startDate and @endDate	
		 group by W.WarehouseName
				,a.ItemMultiMrpId
				,b.MRP
				,a.WarehouseId
				,brand.Categoryid
				,brand.itemBaseName
				,brand.Number
				,cast(a.CreatedDate as date)
				,cast(InDate as date)  
	)innerData
	inner join InventroyProvisioningConfigurations conf  with(nolock)  
		on innerData.Ageing >=  conf.FromDays and innerData.Ageing <=  conf.ToDays 
		and conf.IsActive=1 and conf.IsDeleted=0 
	inner join InventroyProvisioningConfigurationDetails  pcd   with(nolock)   on pcd.InventroyProvisioningConfigurationId = conf.Id and pcd.IsActive=1 and pcd.IsDeleted=0 and pcd.CategoryId = innerData.Categoryid
	
	SELECT   D.WarehouseId
			,D.ItemMultiMRPId
			,D.MRP
			,SUM(OldProvisioning) as OldProvisioning	 
	into #cte	
	FROM (
		select   D.WarehouseId
				,D.ItemMultiMRPId
				,round(D.ClosingAmount   * pcd.Percentage  /100.0,2) as OldProvisioning
				,D.MRP
				--,Case WHEN     				
		FROM InventroyProvisioningDatas D  with(nolock)  
		cross apply(select top 1 * from ItemMasterCentrals imc
		             where imc.ItemMultiMRPId = D.ItemMultiMRPId)x
		inner join InventroyProvisioningConfigurations conf  with(nolock)  
			on D.AgingDays >=  conf.FromDays and D.AgingDays <=  conf.ToDays 
		inner join InventroyProvisioningConfigurationDetails pcd  with(nolock)   on pcd.InventroyProvisioningConfigurationId = conf.Id and pcd.IsActive=1 and pcd.IsDeleted=0 and pcd.CategoryId = x.Categoryid
		
		where CalculationDate =  DATEADD(month, -1, @calcultionDate)
		and (@warehouseId	=0 or WarehouseId = @warehouseId	)
	)D
	
	group by	 D.WarehouseId
				,D.ItemMultiMRPId
				,D.MRP
				
	
	select WarehouseId, ItemMultiMRPId, SUM(FrontMargin) FrontMargin  
	into #tempFrontMargin
	FROM ItemFrontMarginClosings  with(nolock)  
	where (@warehouseId	=0 or WarehouseId = @warehouseId	)
	and CalculationDate = @calcultionDate
	group by WarehouseId, ItemMultiMRPId
					
	set @query = 'select    a.WarehouseId
			 ,a.WarehouseName
			 ,a.ItemMultiMrpId
			 ,a.MRP
			 ,a.Number
			 ,a.itemBaseName
			 ,MAX(#cte.OldProvisioning) as OldProvisioning
			 ,SUM(CAST(a.ClosingQty as bigint)) as ClosingQty
			 ,round(SUM(a.ClosingAmount),2) as ClosingAmount
			 ,' + 
			 @colsWithMaxAndName + 
			 
			 --,MAX(piv.[3]) as [3]
			 --,MAX(piv.[4]) as [4]
			 --,MAX(piv.[5]) as [5]
			 ',round(SUM(a.CurrentProvisioning),2) as TotalProvisioning
			 ,round(SUM(ISNULL(a.CurrentProvisioning, 0)) - ISNULL(MAX(#cte.OldProvisioning), 0),2) as [P/LImpact]
			 ,round((ISNULL(MAX(clos.FrontMargin) ,0) - (SUM(ISNULL(a.CurrentProvisioning, 0)) - ISNULL(MAX(#cte.OldProvisioning), 0))),2) as FinalImpact
			 ,ISNULL(MAX(clos.FrontMargin) ,0) as FrontMargin
	from
	(
		select  ItemMultiMrpId
			   ,MRP
			   ,WarehouseId
			   ,Id

			   ,CurrentProvisioning
		from #tempInventoryProvisioningData
	)p
	pivot
	(
	  SUM(CurrentProvisioning)
	  for id in ('+ @cols + ')
	) piv
	inner join #tempInventoryProvisioningData a 
		on  piv.ItemMultiMrpId = a.ItemMultiMrpId 
		and piv.MRP = a.MRP
		and piv.WarehouseId = a.WarehouseId
	LEFT JOIN #tempFrontMargin clos
		ON 	piv.ItemMultiMrpId = clos.ItemMultiMrpId 
		and piv.WarehouseId = clos.WarehouseId
	LEFT JOIN #cte
		ON 	piv.ItemMultiMrpId = #cte.ItemMultiMrpId 
		and piv.WarehouseId = #cte.WarehouseId
		and piv.MRP = #cte.MRP
	
		
	GROUP BY  a.WarehouseId
			 ,a.WarehouseName
			 ,a.ItemMultiMrpId
			 ,a.MRP
			 ,a.itemBaseName
			 --,a.ClosingQty
			 --,a.ClosingAmount
			 ,a.Number'
	EXECUTE sp_executesql @query
end  

