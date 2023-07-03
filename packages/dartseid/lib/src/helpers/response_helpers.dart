import 'dart:convert';
import 'dart:io';

import 'package:dartseid/dartseid.dart';

void sendErrorResponse(HttpResponse response, DartseidHttpException error) {
  response.statusCode = error.statusCode;
  response.headers.contentType = ContentType.json;
  response.writeln(jsonEncode(error.toJson()));
  response.close();
}

Future<RequestContext> runBeforeHooks(
  RequestContext context,
  BaseRoute route,
) async {
  var ctx = context;

  for (final hook in route.beforeHooks) {
    ctx = await hook(ctx);
  }

  return ctx;
}

Future<({RequestContext context, Object? handleResult})> runAfterHooks(
  RequestContext context,
  BaseRoute route,
  dynamic result,
) async {
  var (ctx, r) = (context, result);

  for (final hook in route.afterHooks) {
    final (newCtx, newR) = await hook(ctx, r);
    ctx = newCtx;
    r = newR;
  }

  return (context: ctx, handleResult: r);
}

void writeNotFoundResponse({
  required RequestContext context,
  required HttpResponse response,
  required RouteHandler? notFoundRouteHandler,
}) {
  response.statusCode = HttpStatus.notFound;

  if (notFoundRouteHandler != null) {
    try {
      response.write(notFoundRouteHandler(context));
      response.close();
      return;
    } on DartseidHttpException catch (e, s) {
      Logger.root.error('$e\n$s');
      return sendErrorResponse(response, e);
    } catch (e, s) {
      Logger.root.error('$e\n$s');
      return sendErrorResponse(response, const InternalServerErrorException());
    }
  }
}

Future<void> writeResponse({
  required RequestContext context,
  required BaseRoute route,
  required HttpResponse response,
}) async {
  try {
    var ctx = await runBeforeHooks(context, route);

    // ignore: argument_type_not_assignable
    var result = route.handler!(ctx);
    if (result is Future) {
      result = await result;
    }

    final (context: newCtx, handleResult: newResult) =
    await runAfterHooks(ctx, route, result);
    ctx = newCtx;
    result = newResult;


    if (result is String) {
      response.headers.contentType = ContentType.html;
    } else {
      result = jsonEncode(result);
      response.headers.contentType = ContentType.json;
    }

    response.write(result);

    response.close();
  } on DartseidHttpException catch (e, s) {
    Logger.root.error('$e\n$s');
    return sendErrorResponse(response, e);
  } catch (e, s) {
    Logger.root.error('$e\n$s');
    return sendErrorResponse(response, const InternalServerErrorException());
  }
}
