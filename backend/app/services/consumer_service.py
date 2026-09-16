"""
app/services/consumer_service.py
"""

from datetime import datetime, timezone

from supabase import Client

from app.core.exceptions import (
    bad_request,
    conflict,
    not_found,
)

from app.models.consumer import (
    ConsumerCreate,
    ConsumerUpdate,
    ConsumerResponse,
    ConsumerSearchRequest,
)


class ConsumerService:


    def __init__(
        self,
        db: Client,
    ):
        self.db = db



    # =========================================================
    # CREATE
    # =========================================================

    def create_consumer(
        self,
        request: ConsumerCreate,
    ) -> ConsumerResponse:


        if self._consumer_exists(
            request.consumer_number
        ):

            raise conflict(
                "Consumer already exists."
            )


        payload = {

            "consumer_number":
            request.consumer_number,

            "account_number":
            request.account_number,

            "consumer_name":
            request.consumer_name,

            "address":
            request.address,

            "meter_number":
            request.meter_number,

            "meter_type":
            request.meter_type.value,

            "subdivision":
            request.subdivision,

            "feeder":
            request.feeder,

            "cycle":
            request.cycle,

        }


        response = (
            self.db
            .table("consumers")
            .insert(payload)
            .execute()
        )


        if not response.data:

            raise bad_request(
                "Unable to create consumer."
            )


        return self._consumer_to_response(
            response.data[0]
        )



    # =========================================================
    # GET ONE
    # =========================================================

    def get_consumer(
        self,
        consumer_id: str,
    ) -> ConsumerResponse:


        consumer = self._get_consumer_record(
            consumer_id
        )


        return self._consumer_to_response(
            consumer
        )



    # =========================================================
    # LIST
    # =========================================================

    def get_all_consumers(
        self,
        page: int = 1,
        page_size: int = 20,
    ) -> list[ConsumerResponse]:


        page = max(page, 1)

        page_size = min(
            max(page_size, 1),
            100
        )


        start = (
            (page - 1)
            * page_size
        )

        end = (
            start
            + page_size
            - 1
        )


        response = (
            self.db
            .table("consumers")
            .select("*")
            .order(
                "created_at",
                desc=True,
            )
            .range(
                start,
                end,
            )
            .execute()
        )


        return [

            self._consumer_to_response(row)

            for row in (
                response.data or []
            )

        ]



    # =========================================================
    # SEARCH
    # =========================================================

    def search_consumers(
        self,
        request: ConsumerSearchRequest,
    ) -> list[ConsumerResponse]:


        query = (
            self.db
            .table("consumers")
            .select("*")
        )


        if request.consumer_number:

            query = query.ilike(
                "consumer_number",
                f"%{request.consumer_number}%",
            )


        if request.account_number:

            query = query.ilike(
                "account_number",
                f"%{request.account_number}%",
            )


        if request.consumer_name:

            query = query.ilike(
                "consumer_name",
                f"%{request.consumer_name}%",
            )


        if request.subdivision:

            query = query.ilike(
                "subdivision",
                f"%{request.subdivision}%",
            )


        response = (
            query
            .order(
                "consumer_name"
            )
            .execute()
        )


        return [

            self._consumer_to_response(row)

            for row in (
                response.data or []
            )

        ]



    # =========================================================
    # UPDATE
    # =========================================================

    def update_consumer(
        self,
        consumer_id: str,
        request: ConsumerUpdate,
    ) -> ConsumerResponse:


        self._get_consumer_record(
            consumer_id
        )


        update_data = {}


        if request.consumer_name:

            update_data[
                "consumer_name"
            ] = request.consumer_name


        if request.address:

            update_data[
                "address"
            ] = request.address


        if request.subdivision:

            update_data[
                "subdivision"
            ] = request.subdivision


        if request.feeder:

            update_data[
                "feeder"
            ] = request.feeder


        if request.cycle:

            update_data[
                "cycle"
            ] = request.cycle



        if not update_data:

            return self.get_consumer(
                consumer_id
            )


        update_data[
            "updated_at"
        ] = datetime.now(
            timezone.utc
        ).isoformat()



        response = (
            self.db
            .table("consumers")
            .update(update_data)
            .eq(
                "id",
                consumer_id,
            )
            .execute()
        )


        if not response.data:

            raise bad_request(
                "Unable to update consumer."
            )


        return self._consumer_to_response(
            response.data[0]
        )



    # =========================================================
    # DELETE
    # =========================================================

    def delete_consumer(
        self,
        consumer_id: str,
    ):


        self._get_consumer_record(
            consumer_id
        )


        response = (
            self.db
            .table("consumers")
            .delete()
            .eq(
                "id",
                consumer_id,
            )
            .execute()
        )


        if not response.data:

            raise bad_request(
                "Unable to delete consumer."
            )



    # =========================================================
    # HELPERS
    # =========================================================

    def _consumer_exists(
        self,
        consumer_number: str,
    ) -> bool:


        response = (
            self.db
            .table("consumers")
            .select("id")
            .eq(
                "consumer_number",
                consumer_number,
            )
            .limit(1)
            .execute()
        )


        return bool(response.data)



    def _get_consumer_record(
        self,
        consumer_id: str,
    ) -> dict:


        response = (
            self.db
            .table("consumers")
            .select("*")
            .eq(
                "id",
                consumer_id,
            )
            .limit(1)
            .execute()
        )


        if not response.data:

            raise not_found(
                "Consumer not found."
            )


        return response.data[0]



    def _consumer_to_response(
        self,
        consumer: dict,
    ) -> ConsumerResponse:


        return ConsumerResponse(

            id=str(
                consumer["id"]
            ),

            consumer_number=
            consumer["consumer_number"],

            account_number=
            consumer["account_number"],

            consumer_name=
            consumer["consumer_name"],

            address=
            consumer["address"],

            meter_number=
            consumer["meter_number"],

            meter_type=
            consumer["meter_type"],

            subdivision=
            consumer.get(
                "subdivision"
            ),

            feeder=
            consumer.get(
                "feeder"
            ),

            cycle=
            consumer.get(
                "cycle"
            ),
        )