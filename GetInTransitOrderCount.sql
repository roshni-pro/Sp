USE [shopkiranamutlimarketcentral]
GO
/****** Object:  StoredProcedure [dbo].[GetInTransitOrderCount]    Script Date: 20-09-2024 17:01:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--Exec GetInTransitOrderCount 1,5
ALTER Proc [dbo].[GetInTransitOrderCount]
--declare
  @warehousId int=1,
  @OrderId int =5
as
begin
Declare @OrderDatetime as datetime=getdate();
Declare @WCapacity int=0,@PendingOrder int=0,@Day int=0
set @WCapacity =(Select top 1 DefaultCapacity from warehousecapacities where WarehouseId=@warehousId and IsActive=1 and IsDeleted=0 and Year=Year(GETDATE())) 

Declare @todayDate DateTime=cast(Getdate() as date),@NextDeliveryDate dateTime,@orderDate Datetime
if @OrderId >0 
begin
  set @OrderDatetime =(select CreatedDate from OrderMasters with(nolock) where Orderid=@OrderId)
  set @todayDate =Cast(@OrderDatetime as date)

  set @orderDate=@todayDate
 -- set @todayDate = DATEADD(hour,48, @todayDate )
End

--select @todayDate

Declare @DeliveryDate DateTime=Cast(DATEADD(hour,48, @todayDate) as date)

Declare @OrderEtaData table(Id int Identity(1,1),NextDeliveryDate DateTime,PendingOrder int,IsDelivered bit)

Declare @OrderaData table(Id int Identity(1,1),DeliveryDate DateTime,ordercount int)


Declare @NextEtaDate table(NextDeliveryDate DateTime,IsDefaultDeliveryChange bit)


Declare @WNextEtaDates table(Id int Identity(1,1),NextDate DateTime,OrderCapacity int)
	   ;with dates_CTE (date) as (
		    select cast(@todayDate as date)
		    Union ALL
		    select DATEADD(day, 1, date)
		    from dates_CTE
		    where date < DATEADD(day,90,cast(@todayDate as date))
		)
	   Insert into @WNextEtaDates(NextDate,OrderCapacity)	  
	   Select a.date, case when wuc.UpdateCapacity is not null then wuc.UpdateCapacity else  
	   case when wh.Id is not null then 0 else @WCapacity end
	   end capacity	   
	   from  dates_CTE a	   
	   left join warehouseholidays wh on  wh.Holidays=DATENAME(WEEKDAY,a.date) and wh.isactive=1 and wh.isdeleted=0 and wh.WarehouseId=@warehousId and wh.Year=Year(GETDATE())
	   left join warehouseupdateCapacities wuc on wuc.Date=a.date and wuc.isactive=1 and wuc.isdeleted=0 and wuc.WarehouseId=@warehousId and wuc.Year=Year(GETDATE())   
	    

if @WCapacity is not null and @WCapacity>0
begin  
        Insert into @OrderaData
		Select Deliverydate,sum(ordercount) ordercount
		from(
		Select  Case when cast(Deliverydate as date)<=@todayDate then @todayDate else cast(deliverydate as date) end DeliveryDate ,count(a.orderid) ordercount 
		from OrderMasters a with(nolock)
		Inner join Customers c with(nolock) on a.CustomerId=c.CustomerId
		 where a.WarehouseId=@warehousId --and cast(Deliverydate as date)<=@DeliveryDate
		and Status in ('Pending','Issued','Shipped','Ready to Dispatch','ReadyToPick','Delivery Redispatch','Delivery Canceled')
		and a.active=1 and a.Deleted=0 and a.OrderType not in (5,6) and a.OrderId!=@OrderId
		and c.CustomerType !='KPP' and c.CustomerType !='SKP'and c.CustomerType!='SKP Retailer' and c.CustomerType!='SKP Owner'
		and c.IsKPP=0
		group  by cast(Deliverydate as date)) a group by a.DeliveryDate
		

		Insert into @OrderEtaData
		Select Deliverydate,cumOrderCount,IsDelivered
		from
		(
		Select  wh.NextDate Deliverydate,isnull(b.ordercount,0) ordercount
		, sum(isnull(b.ordercount,0)
		 -(wh.OrderCapacity)) over(order by wh.NextDate) 		
		  cumOrderCount, case when wh.OrderCapacity=0 then 0 else 1 end IsDelivered
		from  @WNextEtaDates wh
		left join @OrderaData b on wh.NextDate=b.DeliveryDate 
		 ) c 
		
	    
		if exists(select 1 from @OrderEtaData b)
		begin
				Declare @Id int =(select min(Id) from @OrderEtaData b where b.PendingOrder<0 and b.IsDelivered=1 )
				if(@Id is not null)
				begin
				

					Insert into @NextEtaDate 
					Select a.NextDeliveryDate,0 from (
					select ROW_NUMBER() over(order by b.Id) rownum,b.NextDeliveryDate from @OrderEtaData b where b.PendingOrder<0 and b.IsDelivered=1 and b.NextDeliveryDate>=@DeliveryDate
					) a  where a.rownum<=20


					

				End
				else
				begin
				   
				    Set @Id =(select max(Id) from @OrderEtaData b)
				    set @PendingOrder =(select top 1 b.PendingOrder from @OrderEtaData b where Id=@Id)
					
					if(@PendingOrder>0)
					begin
					
					   set @Day= @PendingOrder/@WCapacity
				
					   set @NextDeliveryDate=DATEADD(day,@Day,@DeliveryDate)
					  
					end

					
					Insert into @NextEtaDate 
					 Select a.NextDate,a.IsDefaultChage from (
						select ROW_NUMBER() over(order by b.Id) rownum, b.NextDate,0 IsDefaultChage from @WNextEtaDates b where  b.NextDate>=@NextDeliveryDate and b.OrderCapacity>0
						) a  where a.rownum<=20					
				end  
		 End
		 Else
		 Begin
		       Insert into @NextEtaDate 
			   Select a.NextDate,a.IsDefaultChage from (
                 select ROW_NUMBER() over(order by b.Id) rownum, b.NextDate,0 IsDefaultChage from @WNextEtaDates b where  b.NextDate>=@DeliveryDate and b.OrderCapacity>0
		       ) a  where a.rownum<=20
			 
			   
		 end
		    
	

end
else
begin
   
    Insert into @NextEtaDate
	Select a.NextDate,a.IsDefaultChage from (
            select ROW_NUMBER()  over(order by b.Id) rownum, b.NextDate,0 IsDefaultChage from @WNextEtaDates b where  b.NextDate>=@DeliveryDate and b.OrderCapacity>0
		    ) a  where a.rownum<=20
    
end


  --select * from @OrderEtaData
  --select * from @WNextEtaDates
   
  Update @NextEtaDate set IsDefaultDeliveryChange=case when exists(Select 1 from @NextEtaDate where NextDeliveryDate=@DeliveryDate) then 0 else 1 end

 
  if exists(select 1 from @NextEtaDate)
  begin
    Update @NextEtaDate set NextDeliveryDate=   DATEDIFF(dd, 0,NextDeliveryDate) + CONVERT(DATETIME,CONVERT(VARCHAR(8),@OrderDatetime,108)) 
    --Select * from @NextEtaDate
	---cluster customer validation
	if((select top 1 Holiday from CustomerHolidays  where WarehouseId=@warehousId and IsActive=1 and IsDeleted=0 and CustomerId in (select CustomerId from OrderMasters where OrderId= @OrderId))is null)
	begin
	Select top 4 * from @NextEtaDate where DATENAME(WEEKDAY,NextDeliveryDate) not in
	(select Holiday from ClusterHolidays where WarehouseId=@warehousId and  IsActive=1 and IsDeleted=0 and ClusterId in (select ClusterId from OrderMasters where OrderId= @OrderId))
	end
	else
	begin
	Select top 4 * from @NextEtaDate where DATENAME(WEEKDAY,NextDeliveryDate) not in
	(select Holiday from CustomerHolidays  where WarehouseId=@warehousId and  IsActive=1 and IsDeleted=0 and CustomerId in (select CustomerId from OrderMasters where OrderId= @OrderId))
	end

  end
  else
    begin
	   set @orderDate = case when @orderDate is null then cast(getdate() as date) else @orderDate end
	   --set @orderDate = DATEADD(hour,48, @orderDate )
	   --Select DATEDIFF(dd, 0,a.NextDeliveryDate) + CONVERT(DATETIME,CONVERT(VARCHAR(8),@OrderDatetime,108)),a.IsDefaultDeliveryChange 
	   --from 
	   --(
	   --select DATEADD(day,2, @orderDate )NextDeliveryDate ,cast(0 as bit) IsDefaultDeliveryChange
	   --union all
	   --select DATEADD(day,3, @orderDate ),cast(0 as bit)
    --   union all
	   --select DATEADD(day,4, @orderDate ),cast(0 as bit)
	   --union all
	   --select DATEADD(day,5, @orderDate ),cast(0 as bit)
	   --) a
	   	if((select top 1 Holiday from CustomerHolidays  where WarehouseId=@warehousId and  IsActive=1 and IsDeleted=0 and CustomerId in (select CustomerId from OrderMasters where OrderId= @OrderId))is null)
	begin
	    Select Top 4 DATEDIFF(dd, 0,a.NextDeliveryDate) + CONVERT(DATETIME,CONVERT(VARCHAR(8),@OrderDatetime,108)) NextDeliveryDate,a.IsDefaultDeliveryChange   
    from   
    (  
		select DATEADD(day,2, @orderDate )NextDeliveryDate ,cast(0 as bit) IsDefaultDeliveryChange  
		union all  
		select DATEADD(day,3, @orderDate ),cast(0 as bit)  
		   union all  
		select DATEADD(day,4, @orderDate ),cast(0 as bit)  
		union all  
		select DATEADD(day,5, @orderDate ),cast(0 as bit)  
			union all  
		select DATEADD(day,6, @orderDate ),cast(0 as bit) 
		) a  
		where DATENAME(WEEKDAY,a.NextDeliveryDate) not in
		(select Holiday from ClusterHolidays where WarehouseId=@warehousId and  IsActive=1 and IsDeleted=0 and ClusterId in (select ClusterId from OrderMasters where OrderId= @OrderId))
	end
	else
	begin
	    Select Top 4 DATEDIFF(dd, 0,a.NextDeliveryDate) + CONVERT(DATETIME,CONVERT(VARCHAR(8),@OrderDatetime,108)) NextDeliveryDate,a.IsDefaultDeliveryChange   
		from   
		(  
		select DATEADD(day,2, @orderDate )NextDeliveryDate ,cast(0 as bit) IsDefaultDeliveryChange  
		union all  
		select DATEADD(day,3, @orderDate ),cast(0 as bit)  
		   union all  
		select DATEADD(day,4, @orderDate ),cast(0 as bit)  
		union all  
		select DATEADD(day,5, @orderDate ),cast(0 as bit)  
			union all  
		select DATEADD(day,6, @orderDate ),cast(0 as bit) 
		) a  
		where DATENAME(WEEKDAY,a.NextDeliveryDate) not in
		((select  Holiday from CustomerHolidays  where WarehouseId=@warehousId and  IsActive=1 and IsDeleted=0 and CustomerId in (select CustomerId from OrderMasters where OrderId= @OrderId)))
	end
	end
     
--Select @NextDeliveryDate NextDeliveryDate,cast(case when (@DeliveryDate<@NextDeliveryDate) then 1 else 0 end as bit) IsDefaultDeliveryChange --,@PendingOrder PendingOrder,@Day 



End


