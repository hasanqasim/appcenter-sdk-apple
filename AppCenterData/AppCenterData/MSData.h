// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSSerializableDocument.h"
#import "MSServiceAbstract.h"

@class MSDataError;
@class MSDocumentWrapper;
@class MSPaginatedDocuments;
@class MSReadOptions;
@class MSWriteOptions;

/**
 * App Data service.
 */

NS_ASSUME_NONNULL_BEGIN

/**
 * User partition.
 * An authenticated user can read/write documents in this partition.
 */
static NSString *const kMSDataUserDocumentsPartition = @"user";

/**
 * Application partition.
 * Everyone can read documents in this partition.
 * Writes not allowed via the SDK.
 */
static NSString *const kMSDataAppDocumentsPartition = @"readonly";

/**
 * No expiration on cache.
 */
static int const kMSDataTimeToLiveInfinite = -1;

/**
 * Do not cache.
 */
static int const kMSDataTimeToLiveNoCache = 0;

/**
 * Default expiration on cache.
 */
static int const kMSDataTimeToLiveDefault = 60 * 60 * 24;

@interface MSData : MSServiceAbstract

typedef void (^MSDocumentWrapperCompletionHandler)(MSDocumentWrapper *document);
typedef void (^MSPaginatedDocumentsCompletionHandler)(MSPaginatedDocuments *documents);

/**
 * Change The URL that will be used for getting token.
 *
 * @param tokenExchangeUrl The new URL.
 */
+ (void)setTokenExchangeUrl:(NSString *)tokenExchangeUrl;

/**
 * Read a document.
 * The document type (id<MSSerializableDocument>) must be JSON deserializable.
 *
 * @param partition The CosmosDB partition key.
 * @param documentId The CosmosDB document id.
 * @param documentType The object type of the document. Must conform to MSSerializableDocument protocol.
 * @param completionHandler Callback to accept downloaded document.
 */
+ (void)readWithPartition:(NSString *)partition
               documentId:(NSString *)documentId
             documentType:(Class)documentType
        completionHandler:(MSDocumentWrapperCompletionHandler)completionHandler;

/**
 * Read a document.
 *
 * @param partition The CosmosDB partition key.
 * @param documentId The CosmosDB document id.
 * @param documentType The object type of the document. Must conform to MSSerializableDocument protocol.
 * @param readOptions Options for reading and storing the document.
 * @param completionHandler Callback to accept document.
 */
+ (void)readWithPartition:(NSString *)partition
               documentId:(NSString *)documentId
             documentType:(Class)documentType
              readOptions:(MSReadOptions *_Nullable)readOptions
        completionHandler:(MSDocumentWrapperCompletionHandler)completionHandler;

/**
 * Retrieve a paginated list of the documents in a partition.
 *
 * @param partition The CosmosDB partition key.
 * @param documentType The object type of the documents in the partition. Must conform to MSSerializableDocument protocol.
 * @param completionHandler Callback to accept documents.
 */
+ (void)listWithPartition:(NSString *)partition
             documentType:(Class)documentType
        completionHandler:(MSPaginatedDocumentsCompletionHandler)completionHandler;

/**
 * Create a document in CosmosDB.
 *
 * @param partition The CosmosDB partition key.
 * @param documentId The CosmosDB document id.
 * @param document The document to be stored in CosmosDB. Must conform to MSSerializableDocument protocol.
 * @param completionHandler Callback to accept document.
 */
+ (void)createWithPartition:(NSString *)partition
                 documentId:(NSString *)documentId
                   document:(id<MSSerializableDocument>)document
          completionHandler:(MSDocumentWrapperCompletionHandler)completionHandler;

/**
 * Create a document in CosmosDB.
 *
 * @param partition The CosmosDB partition key.
 * @param documentId The CosmosDB document id.
 * @param document The document to be stored in CosmosDB. Must conform to MSSerializableDocument protocol.
 * @param writeOptions Options for writing and storing the document.
 * @param completionHandler Callback to accept document.
 */
+ (void)createWithPartition:(NSString *)partition
                 documentId:(NSString *)documentId
                   document:(id<MSSerializableDocument>)document
               writeOptions:(MSWriteOptions *_Nullable)writeOptions
          completionHandler:(MSDocumentWrapperCompletionHandler)completionHandler;

/**
 * Replace a document in CosmosDB.
 *
 * @param partition The CosmosDB partition key.
 * @param documentId The CosmosDB document id.
 * @param document The document to be stored in CosmosDB. Must conform to MSSerializableDocument protocol.
 * @param completionHandler Callback to accept document.
 */
+ (void)replaceWithPartition:(NSString *)partition
                  documentId:(NSString *)documentId
                    document:(id<MSSerializableDocument>)document
           completionHandler:(MSDocumentWrapperCompletionHandler)completionHandler;

/**
 * Replace a document in CosmosDB.
 *
 * @param partition The CosmosDB partition key.
 * @param documentId The CosmosDB document id.
 * @param document The document to be stored in CosmosDB. Must conform to MSSerializableDocument protocol.
 * @param writeOptions Options for writing and storing the document.
 * @param completionHandler Callback to accept document.
 */
+ (void)replaceWithPartition:(NSString *)partition
                  documentId:(NSString *)documentId
                    document:(id<MSSerializableDocument>)document
                writeOptions:(MSWriteOptions *_Nullable)writeOptions
           completionHandler:(MSDocumentWrapperCompletionHandler)completionHandler;

/**
 * Delete a document from CosmosDB.
 *
 * @param partition The CosmosDB partition key.
 * @param documentId The CosmosDB document id.
 * @param completionHandler Callback to accept any errors.
 */
+ (void)deleteWithPartition:(NSString *)partition
                 documentId:(NSString *)documentId
          completionHandler:(MSDocumentWrapperCompletionHandler)completionHandler;

/**
 * Delete a document from CosmosDB.
 *
 * @param partition The CosmosDB partition key.
 * @param documentId The CosmosDB document id.
 * @param writeOptions Options for deleting the document.
 * @param completionHandler Callback to accept any errors.
 */
+ (void)deleteWithPartition:(NSString *)partition
                 documentId:(NSString *)documentId
               writeOptions:(MSWriteOptions *_Nullable)writeOptions
          completionHandler:(MSDocumentWrapperCompletionHandler)completionHandler;

@end

NS_ASSUME_NONNULL_END