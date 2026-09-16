from datetime import date, datetime, timedelta

from supabase import Client

from app.models.dashboard import (
    DashboardResponse,
    DashboardFilter,
    DashboardSummary,
    DashboardTrend,
)


class DashboardService:

    def __init__(self, db: Client):
        self.db = db


    # =========================================================
    # MAIN DASHBOARD
    # =========================================================

    def get_dashboard(
        self,
        filters: DashboardFilter,
    ) -> DashboardResponse:

        summary = self.get_summary(filters)

        trends = self.get_trends(filters)

        return self._build_dashboard_response(
            summary,
            trends,
        )


    # =========================================================
    # SUMMARY CARDS
    # =========================================================

    def get_summary(
        self,
        filters: DashboardFilter | None = None,
    ):

        filters = filters or DashboardFilter()


        # -----------------------------
        # Consumers
        # -----------------------------

        consumers_response = (
            self.db
            .table("consumers")
            .select(
                "id",
                count="exact",
            )
            .execute()
        )


        # -----------------------------
        # Total readings
        # -----------------------------

        readings_query = (
            self.db
            .table("meter_readings")
            .select(
                "id",
                count="exact",
            )
        )


        if filters.officer_id:

            readings_query = readings_query.eq(
                "officer_id",
                filters.officer_id,
            )


        if filters.from_date:

            readings_query = readings_query.gte(
                "created_at",
                filters.from_date.isoformat(),
            )


        if filters.to_date:

            readings_query = readings_query.lte(
                "created_at",
                f"{filters.to_date.isoformat()}T23:59:59",
            )


        readings_response = (
            readings_query.execute()
        )


        # -----------------------------
        # Pending readings
        # -----------------------------

        pending_response = (
            self.db
            .table("meter_readings")
            .select(
                "id",
                count="exact",
            )
            .eq(
                "reading_status",
                "pending",
            )
            .execute()
        )


        # -----------------------------
        # Completed today
        # -----------------------------

        today = date.today()


        completed_today_response = (
            self.db
            .table("meter_readings")
            .select(
                "id",
                count="exact",
            )
            .eq(
                "reading_status",
                "completed",
            )
            .gte(
                "created_at",
                datetime.combine(
                    today,
                    datetime.min.time(),
                ).isoformat(),
            )
            .execute()
        )


        # -----------------------------
        # Anomalies
        # -----------------------------

        anomaly_response = (
            self.db
            .table("anomalies")
            .select(
                "id",
                count="exact",
            )
            .eq(
                "status",
                "pending",
            )
            .execute()
        )


        # -----------------------------
        # LCR
        # -----------------------------

        lcr_response = (
            self.db
            .table("lcr_cases")
            .select(
                "id",
                count="exact",
            )
            .eq(
                "status",
                "pending",
            )
            .execute()
        )


        # -----------------------------
        # Sync queue
        # -----------------------------

        sync_response = (
            self.db
            .table("sync_queue")
            .select(
                "id",
                count="exact",
            )
            .eq(
                "sync_status",
                "pending",
            )
            .execute()
        )


        return {

            "total_consumers":
                consumers_response.count or 0,


            "total_readings":
                readings_response.count or 0,


            "completed_today":
                completed_today_response.count or 0,


            "pending_readings":
                pending_response.count or 0,


            "anomalies":
                anomaly_response.count or 0,


            "pending_lcr":
                lcr_response.count or 0,


            "offline_pending":
                sync_response.count or 0,
        }



    # =========================================================
    # TREND GRAPH
    # =========================================================

    def get_trends(
        self,
        filters: DashboardFilter | None = None,
    ):

        filters = filters or DashboardFilter()


        end_date = (
            filters.to_date
            or date.today()
        )


        start_date = (
            filters.from_date
            or end_date - timedelta(days=6)
        )


        readings = (
            self.db
            .table("meter_readings")
            .select(
                "created_at"
            )
            .gte(
                "created_at",
                start_date.isoformat(),
            )
            .lte(
                "created_at",
                f"{end_date.isoformat()}T23:59:59",
            )
            .execute()
        )


        anomalies = (
            self.db
            .table("anomalies")
            .select(
                "created_at"
            )
            .gte(
                "created_at",
                start_date.isoformat(),
            )
            .lte(
                "created_at",
                f"{end_date.isoformat()}T23:59:59",
            )
            .execute()
        )


        reading_count = {}

        anomaly_count = {}


        for row in readings.data or []:

            day = str(
                row["created_at"]
            )[:10]

            reading_count[day] = (
                reading_count.get(day,0)
                + 1
            )


        for row in anomalies.data or []:

            day = str(
                row["created_at"]
            )[:10]

            anomaly_count[day] = (
                anomaly_count.get(day,0)
                + 1
            )


        result = []


        current = start_date


        while current <= end_date:


            key = current.isoformat()


            result.append(
                {
                    "date": current,
                    "readings":
                        reading_count.get(
                            key,
                            0,
                        ),

                    "anomalies":
                        anomaly_count.get(
                            key,
                            0,
                        ),
                }
            )


            current += timedelta(days=1)


        return result



    # =========================================================
    # RESPONSE BUILDER
    # =========================================================

    def _build_dashboard_response(
        self,
        summary,
        trends,
    ):


        return DashboardResponse(

            summary=DashboardSummary(
                **summary
            ),

            trends=[
                DashboardTrend(**trend)
                for trend in trends
            ],
        )