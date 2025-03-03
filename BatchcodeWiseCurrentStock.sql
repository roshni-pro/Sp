USE [shopkiranamutlimarketcentral]
GO
/****** Object:  StoredProcedure [dbo].[BatchcodeWiseCurrentStock]    Script Date: 20-09-2024 17:05:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER proc [dbo].[BatchcodeWiseCurrentStock]
--declare 
@warehouseid int =74
as
begin
select 
c.WarehouseName,
c.ItemNumber,
BM.BatchCode,
c.ItemMultiMRPId,
ic.CategoryName as Category,
ic.SubcategoryName as Subcategory,
c.ItemName,
M.Qty as BatchInventory,
bm.MFGDate,
bm.ExpiryDate,isnull(DATEDIFF(day,GETDATE(),BM.ExpiryDate),0) as RemainingShelfLife
,Round(Isnull(appPrice.APP,0),3) APP
from  StockBatchMasters M with(nolock)
inner join CurrentStocks c with(nolock) on m.StockId=c.StockId and m.StockType='C' and M.IsActive = 1 and M.IsDeleted = 0 
and M.Qty>0 and  c.Deleted = 0 and c.warehouseid =@WarehouseId and c.CurrentInventory>0  
inner join BatchMasters BM with(nolock) ON M.BatchMasterId = BM.Id and  BM.IsDeleted=0 and BM.IsActive=1 
outer apply
  (
	select top 1 ic.CategoryName,ic.SubcategoryName  from ItemMasterCentrals ic with(nolock) where ic.Number=c.ItemNumber
  )ic

   outer apply (select  T.WarehouseId,T.ItemMultiMRPId,    
					   sum(T.qty*T.price)/sum(T.qty) as APP 
					   from    
				   (    
					 select WarehouseId,ItemMultiMRPId,qty,price,    
						 row_number() over(partition by WarehouseId,ItemMultiMRPId order by Createddate desc) as nt                
					 from inqueue with(nolock) where  WarehouseId = c.WarehouseId 
					 and ItemMultiMrpId = c.ItemMultiMRPId 
				   ) as T    
      
				 where nt <= 10 and T.ItemMultiMrpId = c.ItemMultiMRPId    
				 and T.WarehouseId = c.WarehouseId 
				 group by WarehouseId,T.ItemMultiMRPId
	)appPrice

order by ItemMultiMRPId
end
