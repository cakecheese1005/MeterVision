"""
app/services/lcr_service.py
"""

from datetime import datetime, timezone

from supabase import Client

from app.core.exceptions import (
    bad_request,
    not_found,
)

from app.models.lcr import (
    AssignLCR,
    LCRDecision,
    LCRCaseResponse,
)


class LCRService:

    def __init__(self, db: Client):
        self.db = db


    # =========================================================
    # CREATE / ASSIGN LCR CASE
    # =========================================================

    def assign_case(
        self,
        request: AssignLCR,
    ) -> LCRCaseResponse:


        response = (
            self.db
            .table("lcr_cases")
            .insert(
                {
                    "reading_id": request.reading_id,
                    "assigned_to": request.lcr_user_id,
                    "status": "pending",
                }
            )
            .execute()
        )


        if not response.data:
            raise bad_request(
                "Unable to create LCR case."
            )


        return self._case_to_response(
            response.data[0]
        )



    # =========================================================
    # APPROVE
    # =========================================================

    def approve_case(
        self,
        case_id: str,
        request: LCRDecision,
    ) -> LCRCaseResponse:


        self._get_case(case_id)


        response = (
            self.db
            .table("lcr_cases")
            .update(
                {
                    "status": "approved",
                    "remarks": request.remarks,
                    "reviewed_at":
                        datetime.now(
                            timezone.utc
                        ).isoformat(),
                }
            )
            .eq(
                "id",
                case_id,
            )
            .execute()
        )


        if not response.data:
            raise bad_request(
                "Unable to approve LCR case."
            )


        return self._case_to_response(
            response.data[0]
        )



    # =========================================================
    # REJECT
    # =========================================================

    def reject_case(
        self,
        case_id: str,
        request: LCRDecision,
    ) -> LCRCaseResponse:


        self._get_case(case_id)


        response = (
            self.db
            .table("lcr_cases")
            .update(
                {
                    "status": "rejected",
                    "remarks": request.remarks,
                    "reviewed_at":
                        datetime.now(
                            timezone.utc
                        ).isoformat(),
                }
            )
            .eq(
                "id",
                case_id,
            )
            .execute()
        )


        if not response.data:
            raise bad_request(
                "Unable to reject LCR case."
            )


        return self._case_to_response(
            response.data[0]
        )



    # =========================================================
    # GET ONE
    # =========================================================

    def get_case(
        self,
        case_id: str,
    ) -> LCRCaseResponse:


        case = self._get_case(case_id)

        return self._case_to_response(case)



    # =========================================================
    # LIST
    # =========================================================

    def list_cases(self):


        response = (
            self.db
            .table("lcr_cases")
            .select("*")
            .order(
                "created_at",
                desc=True,
            )
            .execute()
        )


        return [
            self._case_to_response(case)
            for case in (
                response.data or []
            )
        ]



    # =========================================================
    # HELPER
    # =========================================================

    def _get_case(
        self,
        case_id: str,
    ):


        response = (
            self.db
            .table("lcr_cases")
            .select("*")
            .eq(
                "id",
                case_id,
            )
            .limit(1)
            .execute()
        )


        if not response.data:
            raise not_found(
                "LCR case not found."
            )


        return response.data[0]



    def _case_to_response(
        self,
        case: dict,
    ) -> LCRCaseResponse:


        return LCRCaseResponse(

            id=str(
                case["id"]
            ),

            reading_id=str(
                case["reading_id"]
            ),

            assigned_to=(
                str(case["assigned_to"])
                if case.get("assigned_to")
                else None
            ),

            status=case["status"],

            remarks=case.get(
                "remarks"
            ),

            updated_at=(
                case.get(
                    "reviewed_at"
                )
                or case["created_at"]
            ),
        )