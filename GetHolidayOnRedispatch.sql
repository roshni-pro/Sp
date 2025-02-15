USE [shopkiranamutlimarketcentral]
GO
/****** Object:  StoredProcedure [dbo].[GetHolidayOnRedispatch]    Script Date: 20-09-2024 17:02:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER proc [dbo].[GetHolidayOnRedispatch]     
--declare     
 @orderId int=2901      
      
  As      
Begin      
      
 Declare @CustomerId int;      
 Declare @ClusterId int;      
 Declare @WarehoiseId int;
 Declare @Deliverydate datetime;
 Declare @OrderDate datetime;

  select      
  @CustomerId= c.CustomerId ,      
  @ClusterId = c.ClusterId,      
  @WarehoiseId = c.Warehouseid ,
  @Deliverydate=om.Deliverydate ,@OrderDate=om.CreatedDate    
   from OrderMasters om      
  inner join Customers c on c.CustomerId = om.CustomerId      
  where om.OrderId=@orderId and om.active=1 and om.Deleted=0      
      
 select TOP 1      
   ch.Holiday Holiday, 'CustomerHoliday' HolidayType,@Deliverydate Deliverydate ,@OrderDate OrderDate  
  from CustomerHolidays ch      
  where ch.IsActive=1 and ch.IsDeleted=0 and ch.CustomerId = @CustomerId  
 union      
 select TOP 1      
    clh.Holiday Holiday, 'ClusterHoliday' HolidayType,@Deliverydate  Deliverydate ,@OrderDate OrderDate
  from ClusterHolidays  clh      
  where clh.IsActive=1 and clh.IsDeleted=0 and clh.ClusterId=@ClusterId
  union
  select distinct    
  Holidays Holiday, 'WarehouseHoliday' HolidayType,@Deliverydate Deliverydate ,@OrderDate OrderDate
  from WarehouseHolidays where WarehouseId =@WarehoiseId       
  and IsActive = 1 and IsDeleted =0   
 end 
 
 
 
 
 

