USE [shopkiranamutlimarketcentral]
GO
/****** Object:  StoredProcedure [Operation].[TripPlanner_CheckRejectedAssignment]    Script Date: 20-09-2024 16:45:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER Procedure [Operation].[TripPlanner_CheckRejectedAssignment]
@TripPlannerConfirmedMasterId bigint = 0
as 
begin

select di.DeliveryIssuanceId from DeliveryIssuances di WITH(nolock) 
where   not exists (
	select 1 from TripPlannerConfirmedOrders o WITH(nolock)
	INNER JOIN TripPlannerConfirmedDetails d WITH(nolock) on o.TripPlannerConfirmedDetailId=d.Id
	INNER JOIN TripPlannerConfirmedMasters m WITH(nolock) on d.TripPlannerConfirmedMasterId=m.Id
	INNER JOIN DeliveryIssuances dii WITH(nolock) on m.Id=dii.TripPlannerConfirmedMasterId
	INNER JOIN OrderDispatchedMasters odm WITH(nolock) on o.OrderId=odm.OrderId and dii.DeliveryIssuanceId=odm.DeliveryIssuanceIdOrderDeliveryMaster
	where m.Id=di.TripPlannerConfirmedMasterId and o.IsActive=1 
	and d.IsActive=1 and d.IsDeleted=0 and d.OrderCount > 0 and di.DeliveryIssuanceId =dii.DeliveryIssuanceId
	group by dii.DeliveryIssuanceId
)  and TripPlannerConfirmedMasterId=@TripPlannerConfirmedMasterId
end
