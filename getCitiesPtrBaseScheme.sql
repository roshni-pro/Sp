USE [shopkiranamutlimarketcentral]
GO
/****** Object:  StoredProcedure [dbo].[getCitiesPtrBaseScheme]    Script Date: 20-09-2024 17:04:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER proc [dbo].[getCitiesPtrBaseScheme]
@itemMultiId int =774
as 
begin
  select w.Cityid from Warehouses w with(nolock)   
  inner join GMWarehouseProgresses b with(nolock) on w.WarehouseId = b.WarehouseID and b.IsLaunched=1   
  and w.active=1 and w.Deleted=0 and w.IsKPP=0 and w.CityName not like '%test%'  
  and not exists (select 1 from ItemSchemes with(nolock) where ItemMultiMRPId=@itemMultiId and Cityid = w.Cityid)  
  group by Cityid  
end
