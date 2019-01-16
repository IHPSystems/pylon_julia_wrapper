include(joinpath("..", "src", "wrapper.jl"))

Wrapper.pylon_initialize()

transport_layer_factory = Wrapper.get_transport_layer_factory_instance()

const images_to_grab = UInt64(100)
const grab_result_wait_timeout_ms = UInt32(100)
const grab_result_retrieve_timeout_ms = UInt32(1)

function acquire_async(camera)
    time_waited = 0.0
    time_retrieved = 0.0
    time_slept = 0.0
    result_ready_cond = Base.AsyncCondition()
    Wrapper.start_grabbing_async(camera, images_to_grab, grab_result_wait_timeout_ms, Wrapper.notify_async_cond_safe_c, result_ready_cond.handle)
    @sync begin
        @async begin
            while Wrapper.is_grabbing(camera)
                t1 = time_ns()
                wait(result_ready_cond)
                t2 = time_ns()
                time_waited += (t2 - t1) / 1e9
                t1 = time_ns()
                grabResult = Wrapper.retrieve_result(camera, grab_result_retrieve_timeout_ms)
                t2 = time_ns()
                time_retrieved += (t2 - t1) / 1e9
                if Wrapper.grab_succeeded(grabResult)
                    width = Wrapper.get_width(grabResult)
                    height = Wrapper.get_height(grabResult)
                    print("Size: $(width) x $(height) : ")
                    buffer = Wrapper.get_buffer(grabResult)
                    buffer_array = unsafe_wrap(Array, Ptr{UInt8}(buffer), (width, height))
                    @show buffer_array[1, 1]
                else
                    println("Error: $(Wrapper.get_error_code(grabResult)) $(Wrapper.get_error_description(grabResult))")
                end
                Wrapper.release(grabResult)
            end
        end
        @async begin
            sleep_delta = 0.001
            while Wrapper.is_grabbing(camera)
                sleep(sleep_delta)
                time_slept += sleep_delta
            end
        end
    end
    Wrapper.stop_grabbing(camera)
    println("Time spent waiting (non-blocking): $(time_waited) secs, mean $(time_waited/images_to_grab)")
    println("Time spent retrieving (blocking): $(time_retrieved) secs, mean $(time_retrieved/images_to_grab)")
    println("Time usable for other tasks: $(time_slept) secs, mean $(time_slept/images_to_grab) secs")
end

try
    device = Wrapper.create_first_device(transport_layer_factory)
    device_info = Wrapper.get_device_info(device)
    vendor_name = Wrapper.get_vendor_name(device_info)
    model_name = Wrapper.get_model_name(device_info)
    serial_number = Wrapper.get_serial_number(device_info)
    println("Using device: $(vendor_name) $(model_name) $(serial_number)")
    camera = Wrapper.InstantCamera(device)
    acquire_async(camera)
catch e
    println(e)
    rethrow(e)
end

Wrapper.pylon_terminate(true)
